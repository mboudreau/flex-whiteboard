////////////////////////////////////////////////////////////////////////////////
//
//  Licensed to the Apache Software Foundation (ASF) under one or more
//  contributor license agreements.  See the NOTICE file distributed with
//  this work for additional information regarding copyright ownership.
//  The ASF licenses this file to You under the Apache License, Version 2.0
//  (the "License"); you may not use this file except in compliance with
//  the License.  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////

package mx.effects
{

import mx.effects.effectClasses.SetPropertyActionInstance;

//--------------------------------------
//  Excluded APIs
//--------------------------------------

[Exclude(name="duration", kind="property")]

[Alternative(replacement="spark.effects.SetAction", since="4.0")]

/**
 *  The SetPropertyAction class defines an action effect that corresponds
 *  to the <code>SetProperty property</code> of a view state definition.
 *  You use a SetPropertyAction effect within a transition definition
 *  to control when the view state change defined by a
 *  <code>SetProperty</code> property occurs during the transition.
 *  
 *  @mxml
 *
 *  <p>The <code>&lt;mx:SetPropertyAction&gt;</code> tag
 *  inherits all of the tag attributes of its superclass,
 *  and adds the following tag attributes:</p>
 * 
 *  <pre>
 *  &lt;mx:SetPropertyAction
 *    <b>Properties</b>
 *    id="ID"
 *    name=""
 *    value=""
 *  /&gt;
 *  </pre>
 *  
 *  @see mx.effects.effectClasses.SetPropertyActionInstance
 *  @see mx.states.SetProperty
 *
 *  @includeExample ../states/examples/TransitionExample.mxml
 *  
 *  @langversion 3.0
 *  @playerversion Flash 9
 *  @playerversion AIR 1.1
 *  @productversion Flex 3
 */
public class SetPropertyAction extends Effect
{
    include "../core/Version.as";

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructor.
	 *
	 *  @param target The Object to animate with this effect.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public function SetPropertyAction(target:Object = null)
	{
		super(target);
        duration = 0;
		instanceClass = SetPropertyActionInstance;
	}
	
	//--------------------------------------------------------------------------
	//
	//  Properties
	//
	//--------------------------------------------------------------------------

	//----------------------------------
	//  name
	//----------------------------------

	[Inspectable(category="General")]
	
	/** 
	 *  The name of the property being changed.
	 *  By default, Flex determines this value from the
	 *  <code>SetProperty</code> property definition
	 *  in the view state definition.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public var name:String;
	
	//----------------------------------
	//  value
	//----------------------------------

	[Inspectable(category="General")]
	
	/** 
	 *  The new value for the property.
	 *  By default, Flex determines this value from the
	 *  <code>SetProperty</code> property definition
	 *  in the view state definition.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public var value:*;
		
	//--------------------------------------------------------------------------
	//
	//  Overridden methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	override public function getAffectedProperties():Array /* of String */
	{
		return [ name ];
	}

	/**
	 *  @private
	 */
	override protected function initInstance(instance:IEffectInstance):void
	{
		super.initInstance(instance);
		
		var actionInstance:SetPropertyActionInstance =
			SetPropertyActionInstance(instance);

		actionInstance.name = name;
		actionInstance.value = value;
	}
}

}
