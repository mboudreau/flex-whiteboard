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
package org.apache.flex.core
{
	import flash.display.Sprite;
	import flash.events.Event;
	
	public class Application extends Sprite
	{
		public function Application()
		{
			super();
			loaderInfo.addEventListener(Event.INIT, initHandler);
		}
		
		private function initHandler(event:Event):void
		{
			valuesImpl = new valuesImplClass as IValuesImpl;
			ValuesManager.valuesImpl = valuesImpl;
			
			initialView = new initialViewClass as ViewBase;
			initialView.addToParent(this);
			initialView.initUI(this);
			dispatchEvent(new Event("viewChanged"));
		}
		
		public var valuesImplClass:Class;
		public var valuesImpl:IValuesImpl;
		
		public var initialViewClass:Class;
		public var initialView:ViewBase;
		
	}
}