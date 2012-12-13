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

package org.apache.flex.js;

import org.apache.flex.compiler.internal.tree.as.LabeledStatementNode;
import org.apache.flex.compiler.internal.tree.as.NamespaceAccessExpressionNode;
import org.apache.flex.compiler.tree.as.IBinaryOperatorNode;
import org.apache.flex.compiler.tree.as.IBlockNode;
import org.apache.flex.compiler.tree.as.ICatchNode;
import org.apache.flex.compiler.tree.as.IClassNode;
import org.apache.flex.compiler.tree.as.IConditionalNode;
import org.apache.flex.compiler.tree.as.IContainerNode;
import org.apache.flex.compiler.tree.as.IDefaultXMLNamespaceNode;
import org.apache.flex.compiler.tree.as.IDynamicAccessNode;
import org.apache.flex.compiler.tree.as.IEmbedNode;
import org.apache.flex.compiler.tree.as.IExpressionNode;
import org.apache.flex.compiler.tree.as.IFileNode;
import org.apache.flex.compiler.tree.as.IForLoopNode;
import org.apache.flex.compiler.tree.as.IFunctionCallNode;
import org.apache.flex.compiler.tree.as.IFunctionNode;
import org.apache.flex.compiler.tree.as.IGetterNode;
import org.apache.flex.compiler.tree.as.IIdentifierNode;
import org.apache.flex.compiler.tree.as.IIfNode;
import org.apache.flex.compiler.tree.as.IInterfaceNode;
import org.apache.flex.compiler.tree.as.IIterationFlowNode;
import org.apache.flex.compiler.tree.as.IKeywordNode;
import org.apache.flex.compiler.tree.as.ILanguageIdentifierNode;
import org.apache.flex.compiler.tree.as.ILiteralNode;
import org.apache.flex.compiler.tree.as.IMemberAccessExpressionNode;
import org.apache.flex.compiler.tree.as.INamespaceNode;
import org.apache.flex.compiler.tree.as.INumericLiteralNode;
import org.apache.flex.compiler.tree.as.IObjectLiteralValuePairNode;
import org.apache.flex.compiler.tree.as.IPackageNode;
import org.apache.flex.compiler.tree.as.IParameterNode;
import org.apache.flex.compiler.tree.as.IReturnNode;
import org.apache.flex.compiler.tree.as.ISetterNode;
import org.apache.flex.compiler.tree.as.ISwitchNode;
import org.apache.flex.compiler.tree.as.ITerminalNode;
import org.apache.flex.compiler.tree.as.ITernaryOperatorNode;
import org.apache.flex.compiler.tree.as.IThrowNode;
import org.apache.flex.compiler.tree.as.ITryNode;
import org.apache.flex.compiler.tree.as.ITypedExpressionNode;
import org.apache.flex.compiler.tree.as.IUnaryOperatorNode;
import org.apache.flex.compiler.tree.as.IVariableNode;
import org.apache.flex.compiler.tree.as.IWhileLoopNode;
import org.apache.flex.compiler.tree.as.IWithNode;
import org.apache.flex.compiler.tree.metadata.IMetaTagNode;
import org.apache.flex.compiler.tree.metadata.IMetaTagsNode;
import org.apache.flex.compiler.units.ICompilationUnit;

/**
 * @author Michael Schmalle
 */
public interface IASBlockVisitor
{
    void visitCompilationUnit(ICompilationUnit unit);

    void visitPackage(IPackageNode element);

    void visitFile(IFileNode node);

    void visitClass(IClassNode node);

    void visitInterface(IInterfaceNode node);

    //--------------------------------------------------------------------------
    
    void visitLanguageIdentifierNode(ILanguageIdentifierNode node);
    
    // block var or field
    void visitVariable(IVariableNode node);
    
    void visitIterationFlow(IIterationFlowNode node);
    
    // is a IVariableNode
    void visitParameter(IParameterNode node);

    void visitFunction(IFunctionNode node);

    void visitGetter(IGetterNode node);

    void visitSetter(ISetterNode node);

    void visitNamespace(INamespaceNode node);
    
    void visitReturn(IReturnNode node);

    //--------------------------------------------------------------------------

    void visitBlock(IBlockNode node);

    void visitContainer(IContainerNode node);

    void visitFunctionCall(IFunctionCallNode node);

    void visitForLoop(IForLoopNode node);

    void visitIf(IIfNode node);
    
    void visitWhileLoop(IWhileLoopNode node);

    void visitTry(ITryNode node);

    void visitCatch(ICatchNode node);

    //--------------------------------------------------------------------------

    void visitKeyword(IKeywordNode node);

    void visitIdentifier(IIdentifierNode node);

    // this is a IBinaryOperatorNode goes before
    void visitDynamicAccess(IDynamicAccessNode node);

    void visitNumericLiteral(INumericLiteralNode node);

    void visitLiteral(ILiteralNode node);

    void visitConditional(IConditionalNode node);

    void visitTerminal(ITerminalNode node);

    void visitBinaryOperator(IBinaryOperatorNode node);

    void visitUnaryOperator(IUnaryOperatorNode node);

    void visitDefaultXMLNamespace(IDefaultXMLNamespaceNode node);

    void visitTypedExpression(ITypedExpressionNode node);

    //
    void visitMetaTags(IMetaTagsNode node);

    void visitMetaTag(IMetaTagNode node);

    void visitEmbed(IEmbedNode node);

    // last

    void visitExpression(IExpressionNode node);
    
    // TODO Figure out if the indirection is useful
    
    void visitConstructor(IFunctionNode node);

    void visitTernaryOperator(ITernaryOperatorNode node);

    void visitMemberAccessExpression(IMemberAccessExpressionNode node);

    void visitNamespaceAccessExpression(NamespaceAccessExpressionNode node);
    
    void visitIObjectLiteralValuePair(IObjectLiteralValuePairNode node);

    void visitSwitch(ISwitchNode node);

    void visitLabeledStatement(LabeledStatementNode node);

    void visitWith(IWithNode node);

    void visitThrow(IThrowNode node);
    

}
