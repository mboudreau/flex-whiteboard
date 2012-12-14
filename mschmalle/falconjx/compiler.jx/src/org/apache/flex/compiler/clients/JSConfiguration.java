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

import org.apache.flex.compiler.config.Configuration;
import org.apache.flex.compiler.config.ConfigurationValue;
import org.apache.flex.compiler.exceptions.ConfigurationException.BadValue;
import org.apache.flex.compiler.internal.config.annotations.Config;
import org.apache.flex.compiler.internal.config.annotations.Mapping;

/**
 * The {@link JSConfiguration} class holds all compiler arguments needed
 * for compiling ActionScript to JavaScript.
 * <p>
 * Specific flags are implemented here for the configuration to be loaded by
 * the configure() method of {@link MXMLJSC}.
 * <p>
 * This class inherits all compiler arguments from the MXMLC compiler.
 * 
 * @author Michael Schmalle
 */
public class JSConfiguration extends Configuration
{
    public JSConfiguration()
    {
    }
    
    //
    // 'mxmljsc.foo-bar' option
    //

    private String fooBar;

    public String getFooBar()
    {
        return fooBar;
    }

    @Config(allowMultiple = false)
    @Mapping({ "mxmljsc", "foo-bar" })
    public void setFooBar(ConfigurationValue cv, String value)
            throws BadValue
    {
        fooBar = value;
    }
}
