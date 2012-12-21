/*
 *
 *  Licensed to the Apache Software Foundation (ASF) under one or more
 *  contributor license agreements.  See the NOTICE file distributed with
 *  this work for additional information regarding copyright ownership.
 *  The ASF licenses this file to You under the Apache License, Version 2.0
 *  (the "License"); you may not use this file except in compliance with
 *  the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

package org.apache.flex.compiler.clients;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.apache.commons.io.FilenameUtils;
import org.apache.flex.compiler.as.IASWriter;
import org.apache.flex.compiler.clients.problems.ProblemPrinter;
import org.apache.flex.compiler.clients.problems.ProblemQuery;
import org.apache.flex.compiler.clients.problems.WorkspaceProblemFormatter;
import org.apache.flex.compiler.common.VersionInfo;
import org.apache.flex.compiler.config.Configuration;
import org.apache.flex.compiler.config.ConfigurationBuffer;
import org.apache.flex.compiler.config.Configurator;
import org.apache.flex.compiler.config.ICompilerSettingsConstants;
import org.apache.flex.compiler.exceptions.ConfigurationException;
import org.apache.flex.compiler.exceptions.ConfigurationException.IOError;
import org.apache.flex.compiler.exceptions.ConfigurationException.MustSpecifyTarget;
import org.apache.flex.compiler.exceptions.ConfigurationException.OnlyOneSource;
import org.apache.flex.compiler.internal.driver.JSBackend;
import org.apache.flex.compiler.internal.js.codgen.JSSharedData;
import org.apache.flex.compiler.internal.projects.CompilerProject;
import org.apache.flex.compiler.internal.projects.FlexProject;
import org.apache.flex.compiler.internal.projects.ISourceFileHandler;
import org.apache.flex.compiler.internal.targets.JSTarget;
import org.apache.flex.compiler.internal.units.ResourceModuleCompilationUnit;
import org.apache.flex.compiler.internal.units.SourceCompilationUnitFactory;
import org.apache.flex.compiler.internal.workspaces.Workspace;
import org.apache.flex.compiler.js.IJSApplication;
import org.apache.flex.compiler.problems.ConfigurationProblem;
import org.apache.flex.compiler.problems.ICompilerProblem;
import org.apache.flex.compiler.problems.InternalCompilerProblem;
import org.apache.flex.compiler.problems.UnableToBuildSWFProblem;
import org.apache.flex.compiler.problems.UnexpectedExceptionProblem;
import org.apache.flex.compiler.projects.ICompilerProject;
import org.apache.flex.compiler.targets.ITarget;
import org.apache.flex.compiler.targets.ITargetSettings;
import org.apache.flex.compiler.units.ICompilationUnit;
import org.apache.flex.utils.FileUtils;
import org.apache.flex.utils.FilenameNormalization;

import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableSet;
import com.google.common.collect.Iterables;

/**
 * @author Michael Schmalle
 */
public class MXMLJSC
{

    /*
     * Exit code enumerations.
     */
    static enum ExitCode
    {
        SUCCESS(0),
        PRINT_HELP(1),
        FAILED_WITH_PROBLEMS(2),
        FAILED_WITH_EXCEPTIONS(3),
        FAILED_WITH_CONFIG_PROBLEMS(4);

        ExitCode(int code)
        {
            this.code = code;
        }

        final int code;
    }

    /**
     * Java program entry point.
     * 
     * @param args command line arguments
     */
    public static void main(final String[] args)
    {
        long startTime = System.nanoTime();

        final IBackend backend = new JSBackend();
        final MXMLJSC mxmlc = new MXMLJSC(backend);
        final Set<ICompilerProblem> problems = new HashSet<ICompilerProblem>();
        final int exitCode = mxmlc.mainNoExit(args, problems, true);

        long endTime = System.nanoTime();
        JSSharedData.instance.stdout((endTime - startTime) / 1e9 + " seconds");

        System.exit(exitCode);
    }

    private Workspace workspace;
    private FlexProject project;
    private ProblemQuery problems;
    private ISourceFileHandler asFileHandler;
    private Configuration config;
    private Configurator projectConfigurator;
    private ConfigurationBuffer configBuffer;
    private ICompilationUnit mainCU;
    private ITarget target;
    private ITargetSettings targetSettings;
    private IJSApplication jsTarget;

    protected MXMLJSC(IBackend backend)
    {
        JSSharedData.backend = backend;
        workspace = new Workspace();
        project = new FlexProject(workspace);
        problems = new ProblemQuery();
        JSSharedData.OUTPUT_EXTENSION = backend.getOutputExtension();
        JSSharedData.workspace = workspace;
        asFileHandler = backend.getSourceFileHandlerInstance();
    }

    public int mainNoExit(final String[] args, Set<ICompilerProblem> problems,
            Boolean printProblems)
    {
        int exitCode = -1;
        try
        {
            exitCode = _mainNoExit(fixArgs(args), problems);
        }
        catch (Exception e)
        {
            JSSharedData.instance.stderr(e.toString());
        }
        finally
        {
            if (problems != null && !problems.isEmpty())
            {
                if (printProblems)
                {
                    final WorkspaceProblemFormatter formatter = new WorkspaceProblemFormatter(
                            workspace);
                    final ProblemPrinter printer = new ProblemPrinter(formatter);
                    printer.printProblems(problems);
                }
            }
        }
        return exitCode;
    }

    /**
     * Entry point that doesn't call <code>System.exit()</code>. This is for
     * unit testing.
     * 
     * @param args command line arguments
     * @return exit code
     */
    private int _mainNoExit(final String[] args,
            Set<ICompilerProblem> outProblems)
    {
        ExitCode exitCode = ExitCode.SUCCESS;
        try
        {
            final boolean continueCompilation = configure(args);

            if (outProblems != null && !config.isVerbose())
                JSSharedData.STDOUT = JSSharedData.STDERR = null;

            if (continueCompilation)
            {
                compile();
                if (problems.hasFilteredProblems())
                    exitCode = ExitCode.FAILED_WITH_PROBLEMS;
            }
            else if (problems.hasFilteredProblems())
            {
                exitCode = ExitCode.FAILED_WITH_CONFIG_PROBLEMS;
            }
            else
            {
                exitCode = ExitCode.PRINT_HELP;
            }
        }
        catch (Exception e)
        {
            if (outProblems == null)
                JSSharedData.instance.stderr(e.getMessage());
            else
            {
                final ICompilerProblem unexpectedExceptionProblem = new UnexpectedExceptionProblem(
                        e);
                problems.add(unexpectedExceptionProblem);
            }
            exitCode = ExitCode.FAILED_WITH_EXCEPTIONS;
        }
        finally
        {
            waitAndClose();

            if (outProblems != null && problems.hasFilteredProblems())
            {
                for (ICompilerProblem problem : problems.getFilteredProblems())
                {
                    outProblems.add(problem);
                }
            }
        }
        return exitCode.code;
    }

    /**
     * Main body of this program. This method is called from the public static
     * method's for this program.
     * 
     * @return true if compiler succeeds
     * @throws IOException
     * @throws InterruptedException
     */
    protected boolean compile()
    {
        boolean compilationSuccess = false;

        try
        {
            setupJS();
            if (!setupTargetFile())
                return false;

            //if (config.isDumpAst())
            //    dumpAST();

            buildArtifact();

            if (jsTarget != null)
            {
                Collection<ICompilerProblem> errors = new ArrayList<ICompilerProblem>();
                Collection<ICompilerProblem> warnings = new ArrayList<ICompilerProblem>();

                // Don't create a swf if there are errors unless a 
                // developer requested otherwise.
                if (!config.getCreateTargetWithErrors())
                {
                    problems.getErrorsAndWarnings(errors, warnings);
                    if (errors.size() > 0)
                        return false;
                }

                final File outputFile = new File(getOutputFilePath());

                final File outputFolder = new File(outputFile.getParent());
                List<ICompilationUnit> reachableCompilationUnits = project
                        .getReachableCompilationUnitsInSWFOrder(ImmutableSet
                                .of(mainCU));
                for (final ICompilationUnit cu : reachableCompilationUnits)
                {
                    if (cu.getCompilationUnitType() == ICompilationUnit.UnitType.AS_UNIT
                            && cu != mainCU)
                    {
                        final File outputClassFile = new File(
                                outputFolder.getAbsolutePath() + File.separator
                                        + cu.getShortNames().get(0) + ".js");
                        System.out.println(outputClassFile.getAbsolutePath());

                        for (ICompilationUnit unit : reachableCompilationUnits)
                        {
                            IASWriter jswriter = JSSharedData.backend
                                    .createWriter(project,
                                            (List<ICompilerProblem>) errors,
                                            unit, false);

                            if (unit.getCompilationUnitType() != ICompilationUnit.UnitType.AS_UNIT)
                                continue;

                            // XXX hack what is CountingOutputStream?
                            BufferedOutputStream out = new BufferedOutputStream(
                                    new FileOutputStream(outputClassFile));
                            jswriter.writeTo(out);
                            out.flush();
                            out.close();
                            jswriter.close();
                        }
                    }
                }
                compilationSuccess = true;

                //dumpDependencyGraphIfNeeded();
            }
        }
        catch (Exception e)
        {
            final ICompilerProblem problem = new InternalCompilerProblem(e);
            problems.add(problem);
        }

        return compilationSuccess;
    }

    /**
     * Build target artifact.
     * 
     * @throws InterruptedException threading error
     * @throws IOException IO error
     * @throws ConfigurationException
     */
    protected void buildArtifact() throws InterruptedException, IOException,
            ConfigurationException
    {
        jsTarget = buildJSTarget();
    }

    private IJSApplication buildJSTarget() throws InterruptedException,
            FileNotFoundException, ConfigurationException
    {
        final List<ICompilerProblem> problemsBuildingSWF = new ArrayList<ICompilerProblem>();

        final IJSApplication app = buildApplication(project,
                config.getMainDefinition(), mainCU, problemsBuildingSWF);
        problems.addAll(problemsBuildingSWF);
        if (app == null)
        {
            ICompilerProblem problem = new UnableToBuildSWFProblem(
                    getOutputFilePath());
            problems.add(problem);
        }

        //reportRequiredRSLs(target);

        return app;
    }

    /**
     * Replaces FlexApplicationProject::buildSWF()
     * 
     * @param applicationProject
     * @param rootClassName
     * @param problems
     * @return
     * @throws InterruptedException
     */

    private IJSApplication buildApplication(CompilerProject applicationProject,
            String rootClassName, ICompilationUnit mainCU,
            Collection<ICompilerProblem> problems) throws InterruptedException,
            ConfigurationException, FileNotFoundException
    {
        Collection<ICompilerProblem> fatalProblems = applicationProject
                .getFatalProblems();
        if (!fatalProblems.isEmpty())
        {
            problems.addAll(fatalProblems);
            return null;
        }

        return ((JSTarget) target).build(mainCU, problems);
    }

    /**
     * Get the output file path. If {@code -output} is specified, use its value;
     * otherwise, use the same base name as the target file.
     * 
     * @return output file path
     */
    private String getOutputFilePath()
    {
        if (config.getOutput() == null)
        {
            final String extension = "." + JSSharedData.OUTPUT_EXTENSION;
            return FilenameUtils.removeExtension(config.getTargetFile())
                    .concat(extension);
        }
        else
            return config.getOutput();
    }

    /**
     * Mxmlc uses target file as the main compilation unit and derive the output
     * SWF file name from this file.
     * 
     * @return true if successful, false otherwise.
     * @throws OnlyOneSource
     * @throws InterruptedException
     */
    protected boolean setupTargetFile() throws InterruptedException
    {
        final String mainFileName = config.getTargetFile();

        final String normalizedMainFileName = FilenameNormalization
                .normalize(mainFileName);

        final SourceCompilationUnitFactory compilationUnitFactory = project
                .getSourceCompilationUnitFactory();

        File normalizedMainFile = new File(normalizedMainFileName);
        if (compilationUnitFactory.canCreateCompilationUnit(normalizedMainFile))
        {
            // adds the source path to the sourceListManager
            project.addIncludeSourceFile(normalizedMainFile);

            // just using the basename is obviously wrong:
            // final String mainQName = FilenameUtils.getBaseName(normalizedMainFile);

            final List<String> sourcePath = config.getCompilerSourcePath();
            String mainQName = null;
            if (sourcePath != null && !sourcePath.isEmpty())
            {
                for (String path : sourcePath)
                {
                    final String otherPath = new File(path).getAbsolutePath();
                    if (mainFileName.startsWith(otherPath))
                    {
                        mainQName = mainFileName
                                .substring(otherPath.length() + 1);
                        mainQName = mainQName.replaceAll("\\\\", "/");
                        mainQName = mainQName.replaceAll("\\/", ".");
                        if (mainQName.endsWith(".as"))
                            mainQName = mainQName.substring(0,
                                    mainQName.length() - 3);
                        break;
                    }
                }
            }

            if (mainQName == null)
                mainQName = FilenameUtils.getBaseName(mainFileName);

            Collection<ICompilationUnit> mainFileCompilationUnits = workspace
                    .getCompilationUnits(normalizedMainFileName, project);

            //assert mainFileCompilationUnits.size() == 1;
            mainCU = Iterables.getOnlyElement(mainFileCompilationUnits);

            //assert ((DefinitionPriority)mainCU.getDefinitionPriority()).getBasePriority() == DefinitionPriority.BasePriority.SOURCE_LIST;

            // Use main source file name as the root class name.
            config.setMainDefinition(mainQName);
        }

        Preconditions.checkNotNull(mainCU,
                "Main compilation unit can't be null");

        // if (getTargetSettings() == null)
        //     return false;

        target = (JSTarget) JSSharedData.backend.createTarget(project,
                getTargetSettings(), null);

        return true;
    }

    private ITargetSettings getTargetSettings()
    {
        if (targetSettings == null)
            targetSettings = projectConfigurator.getTargetSettings(null);

        return targetSettings;
    }

    private void setupJS() throws IOException, InterruptedException
    {
        // JSSharedData.instance.reset();
        project.getSourceCompilationUnitFactory().addHandler(asFileHandler);

        // JSSharedData.instance.setVerbose(config.isVerbose());

        //JSSharedData.DEBUG = config.debug();
        //JSSharedData.OPTIMIZE = !config.debug() && config.optimize();

        //--- final Set<ICompilationUnit> compilationUnits = new HashSet<ICompilationUnit>();

        // XXX // add builtins?

        registerSWCs(project); // XXX is this needed?
    }

    public static void registerSWCs(CompilerProject project)
            throws InterruptedException
    {
        //        final JSSharedData sharedData = JSSharedData.instance;
        //
        //        // collect all SWCCompilationUnit in swcUnits
        //        final List<ICompilationUnit> swcUnits = new ArrayList<ICompilationUnit>();
        //        for (ICompilationUnit cu : project.getCompilationUnits())
        //        {
        //            //            if (cu instanceof SWCCompilationUnit)
        //            //                swcUnits.add(cu);
        //            //
        //            //            final List<IDefinition> defs = getDefinitions(cu, false);
        //            //            for (IDefinition def : defs)
        //            //            {
        //            //                sharedData.registerDefinition(def);
        //            //            }
        //        }

    }

    /**
     * Create a new Configurator. This method may be overridden to allow
     * Configurator subclasses to be created that have custom configurations.
     * 
     * @return a new instance or subclass of {@link Configurator}.
     */
    protected Configurator createConfigurator()
    {
        return JSSharedData.backend.createConfigurator();
    }

    /**
     * Load configurations from all the sources.
     * 
     * @param args command line arguments
     * @return True if mxmlc should continue with compilation.
     */
    protected boolean configure(final String[] args)
    {
        project.getSourceCompilationUnitFactory().addHandler(asFileHandler);
        projectConfigurator = createConfigurator();

        try
        {
            //            // Print brief usage if no arguments provided.
            //            if (args.length == 0)
            //            {
            //                final String usage = CommandLineConfigurator.brief(
            //                        getProgramName(), DEFAULT_VAR,
            //                        LocalizationManager.get(), L10N_CONFIG_PREFIX);
            //                if (usage != null)
            //                    println(usage);
            //                return false;
            //            }
            //
            projectConfigurator.setConfiguration(args,
                    ICompilerSettingsConstants.FILE_SPECS_VAR);
            projectConfigurator.applyToProject(project);
            problems = new ProblemQuery(
                    projectConfigurator.getCompilerProblemSettings());

            // Get the configuration and configBuffer which are now initialized.
            config = projectConfigurator.getConfiguration();
            configBuffer = projectConfigurator.getConfigurationBuffer();
            problems.addAll(projectConfigurator.getConfigurationProblems());

            // Print version if "-version" is present.
            if (configBuffer.getVar("version") != null) //$NON-NLS-1$
            {
                println(VersionInfo.buildMessage() + " ("
                        + JSSharedData.COMPILER_VERSION + ")");
                return false;
            }
            //
            //            // Print help if "-help" is present.
            //            final List<ConfigurationValue> helpVar = configBuffer
            //                    .getVar("help"); //$NON-NLS-1$
            //            if (helpVar != null)
            //            {
            //                processHelp(helpVar);
            //                return false;
            //            }
            //
            //            for (String fileName : projectConfigurator
            //                    .getLoadedConfigurationFiles())
            //            {
            //                JSSharedData.instance.stdout("Loading configuration: "
            //                        + fileName);
            //            }
            //
            //            if (config.isVerbose())
            //            {
            //                for (final IFileSpecification themeFile : project
            //                        .getThemeFiles())
            //                {
            //                    JSSharedData.instance.stdout(String.format(
            //                            "Found theme file %s", themeFile.getPath()));
            //                }
            //            }
            //
            // If we have configuration errors then exit before trying to 
            // validate the target.
            if (problems.hasErrors())
                return false;

            validateTargetFile();
            return true;
        }
        catch (ConfigurationException e)
        {
            final ICompilerProblem problem = new ConfigurationProblem(e);
            problems.add(problem);
            return false;
        }
        catch (Exception e)
        {
            final ICompilerProblem problem = new ConfigurationProblem(null, -1,
                    -1, -1, -1, e.getMessage());
            problems.add(problem);
            return false;
        }
        finally
        {
            // If we couldn't create a configuration, then create a default one
            // so we can exit without throwing an exception.
            if (config == null)
            {
                config = new Configuration();
                configBuffer = new ConfigurationBuffer(Configuration.class,
                        Configuration.getAliases());
            }
        }
    }

    /**
     * Validate target file.
     * 
     * @throws MustSpecifyTarget
     * @throws IOError
     */
    protected void validateTargetFile() throws ConfigurationException
    {
        if (mainCU instanceof ResourceModuleCompilationUnit)
            return; //when compiling a Resource Module, no target file is defined.

        final String targetFile = config.getTargetFile();
        if (targetFile == null)
            throw new ConfigurationException.MustSpecifyTarget(null, null, -1);

        final File file = new File(targetFile);
        if (!file.exists())
            throw new ConfigurationException.IOError(targetFile);
    }

    private void println(String string)
    {
        // TODO Auto-generated method stub

    }

    /**
     * Wait till the workspace to finish compilation and close.
     */
    protected void waitAndClose()
    {
        workspace.startIdleState();
        try
        {
            workspace.close();
        }
        finally
        {
            workspace.endIdleState(Collections
                    .<ICompilerProject, Set<ICompilationUnit>> emptyMap());
        }
    }

    /**
     * Force terminate the compilation process.
     */
    protected void close()
    {
        workspace.close();
    }

    // workaround for Falcon bug.
    // Input files with relative paths confuse the algorithm that extracts the root class name.

    protected static String[] fixArgs(final String[] args)
    {
        String[] newArgs = args;
        if (args.length > 1)
        {
            String targetPath = args[args.length - 1];
            if (targetPath.startsWith("."))
            {
                targetPath = FileUtils
                        .getTheRealPathBecauseCanonicalizeDoesNotFixCase(new File(
                                targetPath));
                newArgs = new String[args.length];
                for (int i = 0; i < args.length - 1; ++i)
                    newArgs[i] = args[i];
                newArgs[args.length - 1] = targetPath;
            }
        }
        return newArgs;
    }
}
