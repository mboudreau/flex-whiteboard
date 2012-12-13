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

package org.apache.flex.compiler.internal.driver.strategy;

import org.apache.flex.compiler.internal.js.codgen.JSEmitter;
import org.apache.flex.compiler.tree.ASTNodeID;
import org.apache.flex.compiler.tree.as.IASNode;
import org.apache.flex.compiler.tree.as.IContainerNode;
import org.apache.flex.compiler.tree.as.IContainerNode.ContainerType;
import org.apache.flex.compiler.visitor.IASNodeStrategy;

public class BeforeNodeStrategy implements IASNodeStrategy
{

    private final JSEmitter emitter;

    public BeforeNodeStrategy(JSEmitter emitter)
    {
        this.emitter = emitter;
    }

    @Override
    public void handle(IASNode node)
    {
        if (node.getNodeID() == ASTNodeID.BlockID)
        {
            IASNode parent = node.getParent();
            IContainerNode container = (IContainerNode) node;
            ContainerType type = container.getContainerType();

            if (parent.getNodeID() != ASTNodeID.LabledStatementID)
            {
                if (node.getChildCount() != 0)
                    emitter.indentPush();
            }
            
            // switch cases are SYNTHESIZED
            if (type != ContainerType.IMPLICIT
                    && type != ContainerType.SYNTHESIZED)
            {
                emitter.write("{");
            }

            if (parent.getNodeID() != ASTNodeID.LabledStatementID)
            {
                emitter.write("\n");
            }
        }
    }

}
