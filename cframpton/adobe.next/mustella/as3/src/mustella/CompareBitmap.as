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
package  { 

import flash.display.IBitmapDrawable;
import flash.utils.*;
import flash.net.*;
import flash.events.*;
import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import mx.core.mx_internal;
use namespace mx_internal;

/**
*  Vector of conditionalValue objects.
**/
[DefaultProperty("conditionalValues")]

/**
 *  The test step that compares a bitmap against a reference bitmap
 *  MXML attributes:
 *  target
 *  url
 *  timeout (optional);
 *  maxColorVariance
 *  numColorVariances
 *  waitTarget Do Not Use
 *  waitEvent Do Not Use
 *  stageText - placeholder, does nothing
 *
 *
 *  Do not set waitEvent or waitTarget on this step.  They are set internally
 *  to manage the loading of the reference bitmap.  The step prior to this
 *  step must wait for the system to synch up.
 *  
 *  CompareBitmap will parse the url attribute for $testID, replacing with the current testID
 */
public class CompareBitmap extends Assert
{ 
	public static var useRemoteDiffer:Boolean = false;

	public static var DEFAULT_MAX_COLOR_VARIANCE:int = 0;
	public static var DEFAULT_NUM_COLOR_VARIANCES:int = 0;

	// This is the default property.
	public var conditionalValues:Vector.<ConditionalValue> = null;
	
	/**
	 *  The url of the file to read. If UnitTester.createBitmapReferences = true,
	 *  the url to store the bitmap
	 */
	public var url:String;

	
	/**
	 *  placeHolder for stageText, does nothing
	 */
	public var stageText:String;

	private var _maxColorVariance:int = 0;
	/**
	 *  The maximum color variation allowed in a bitmap compare.
	 *  Some machines render slightly differently and thus we have
	 *  to allow the the compare to not be exact.
	 */
	public function get maxColorVariance():int
	{
		if (_maxColorVariance)
			return _maxColorVariance;

		return DEFAULT_MAX_COLOR_VARIANCE;
	}
	public function set maxColorVariance(value:int):void
	{
		_maxColorVariance = value;
	}

	private var _ignoreMaxColorVariance:Boolean = false;
	
	/**
	 * Sometimes you have numColorVariance defined and you don't really care by how much the pixel really differ.
	 * as long as the number of mismatching pixels is &lt;= numColorVariance
	 * Setting this to true will skip the maxColorVariance check (and take the guess work out of picture). default is false
	 */
	public function get ignoreMaxColorVariance():Boolean
	{
		return _ignoreMaxColorVariance;
	}
	
	public function set ignoreMaxColorVariance(value:Boolean):void
	{
		_ignoreMaxColorVariance = value;
	}


	private var _numColorVariances:int = 0;
	/**
	 *  The number of color variation allowed in a bitmap compare.
	 *  Some machines render slightly differently and thus we have
	 *  to allow the the compare to not be exact.
	 */
	public function get numColorVariances():int
	{
		if (_numColorVariances)
			return _numColorVariances;

		return DEFAULT_NUM_COLOR_VARIANCES;
	}
	public function set numColorVariances(value:int):void
	{
		_numColorVariances = value;
	}

	/**
	 *  Suffix to add to the file being written out (the case of a compare failure)
	 */
	public static var fileSuffix:String = "";

	private var reader:Loader;
	private var writer:URLLoader;

	private static var connection:LocalConnection;
	private static var commandconnection:LocalConnection;
	
	private var baselineMissing:Boolean = false;
	private var baselineMissingMessage:String = "Baseline image could not be read.  Created image file as a .bad.png.";
	private var baselineMissingMessageFail:String = "Baseline image could not be read, and we failed to write the .bad.png";
	
	private function statusHandler(event:Event):void
	{
	}

	/**
	 *  Constructor
	 */
	public function CompareBitmap() 
	{ 
		if (!connection)
		{
			connection = new LocalConnection();
			connection.allowDomain("*");
			connection.addEventListener(StatusEvent.STATUS, statusHandler);

			commandconnection = new LocalConnection();
			commandconnection.allowDomain("*");

			try
			{
				commandconnection.connect("_ImageDifferCommands");
			}
			catch (e:Error)
			{
				trace("connection failed");
			}
		}

	}

	override public function execute(root:DisplayObject, context:UnitTester, testCase:TestCase, testResult:TestResult):Boolean
	{
		var cv:ConditionalValue = null;
		var configID:String = null;
		
		// Use MultiResult to determine the proper URL.
		if(conditionalValues){
			cv = new MultiResult().chooseCV(conditionalValues);
			if(cv){
				// This way, we use CompareBitmap's url (directory) if the CV's is not set.
				if( cv.url != null ){
					url = cv.url;
				}
			}
		}else{
			// We do not have ConditionalValues.  If the current config is unknown, it is probably
			// a desktop AIR run, and we should just let things take the course they always have.
			// If a config is known, then we want to use the new config ID suffix mechanism later.
			configID = TargetConfigurations.getTargetConfigID( UnitTester.cv );
			if( configID ){
				trace( "CompareBitmap: No ConditionalValues found.  configID is " + configID.toString() );
			}else{
				trace( "CompareBitmap: No ConditionalValues found.  configID is " + configID );
			}
		}

		if( url == null ){
			if( cv == null ){
				throw new Error("Found no url on the CompareBitmap for test case " + testCase.testID);
			}else{
				throw new Error("Found no url on the ConditionalValue for test case " + testCase.testID + ", ConditionalValue: " + cv.toString());
			}
		}

		// See if url ends with .png.  If not, create a file name.
		if( url.lastIndexOf( ".png" ) != url.length - 4 ){
			
			// Add a path separator if necessary.
			if( url.lastIndexOf( "/" ) != url.length - 1 ){
				url += "/";
			}		

			// Decide on a file name.
			if( conditionalValues ){
				// If we ended up with a matching CV, ask it to create a file name.
				// Otherwise, go with the test ID.
				// Keep this path alive until (if ever) ConditionalValues in CompareBitmaps have all been removed.
				if(cv){
					trace( "CompareBitmap: Asking the ConditionalValue to create the file name." );
					url += cv.createFilename( testCase.testID );
				} else {
					trace( "CompareBitmap: Creating the file name from the testID." );
					url += testCase.testID + ".png";
				}
			}else if( configID ){
				// We have no ConditionalValues and we're running a known config,
				// so use the config id in the suffix.
				trace( "CompareBitmap: Creating the file name from the configID." );
				url += testCase.testID + "@" + configID + ".png";
			}else{
				trace( "There is no file name, there are no Conditional Values, and there is no configID.  There's not much we can do now, is there?" );
			}
		}
		
		if (url != null && url.indexOf ("$testID") != -1) { 
			trace ("SAW THE REF, I'll plug it");
			url = url.replace ("$testID", UnitTester.currentTestID);
			trace ("result 2: " + url);
		}

		if (url == null)
			trace ("URL was null at execute time");

		if (commandconnection)
			commandconnection.client = this;

		var actualTarget:DisplayObject = DisplayObject(context.stringToObject(target));
		if (!actualTarget)
		{
			testResult.doFail("Target " + target + " not found");
			return true;
		}

		this.root = root;
		this.context = context;
		this.testResult = testResult;

		if (UnitTester.createBitmapReferences)
		{
			if (UnitTester.checkEmbeddedFonts)
			{
				if (!checkEmbeddedFonts(actualTarget))
				{
					testResult.doFail ("Target " + actualTarget + " is using non-embedded or advanced anti-aliased fonts");	
					return true;
				}
			}

			writePNG(actualTarget);
			return false;
		}
		else
		{
			readPNG();
			return false;
		}

	}

	private function getTargetSize(target:DisplayObject):Point
	{
		var width:Number;
		var height:Number;

        try
        {  
            width = target["getUnscaledWidth"]() * Math.abs(target.scaleX) * target.root.scaleX;
            height = target["getUnscaledHeight"]() * Math.abs(target.scaleY) * target.root.scaleY;
        }
        catch(e:ReferenceError)
        {
            width = target.width * target.root.scaleX;
            height = target.height * target.root.scaleY;
        }
		return new Point(width, height);
	}

	// Given a displayObject, sets up the screenBits.
	private function getScreenBits(target:DisplayObject):void{
		try 
		{
			var targetSize:Point = getTargetSize(target);
			var stagePt:Point = target.localToGlobal(new Point(0, 0));
            var altPt:Point = target.localToGlobal(targetSize);
            stagePt.x = Math.min(stagePt.x, altPt.x);
            stagePt.y = Math.min(stagePt.y, altPt.y);
			screenBits = new BitmapData(targetSize.x, targetSize.y);
			screenBits.draw(target.stage, new Matrix(1, 0, 0, 1, -stagePt.x, -stagePt.y));
		}
		catch (se:SecurityError)
		{
			UnitTester.hideSandboxes();
			try
			{
				screenBits.draw(target.stage, new Matrix(1, 0, 0, 1, -stagePt.x, -stagePt.y));
			}
			catch (se2:Error)
			{
				try 
				{
					// if we got a security error and ended up here, assume we're in the
					// genericLoader loads us scenario
					screenBits.draw(target.root, new Matrix(1, 0, 0, 1, -stagePt.x, -stagePt.y));
				}
				catch (se3:Error)
				{
				}
			}
			UnitTester.showSandboxes();
			var sb:Array = UnitTester.getSandboxBitmaps();
			var n:int = sb.length;
			for (var i:int = 0; i < n; i++)
			{
				mergeSandboxBitmap(target, stagePt, screenBits, sb[i]);
			}
		}
		catch (e:Error)
		{
			testResult.doFail (e.getStackTrace());	
		}
	}

	private var MAX_LC:int = 12000;
	private var screenBits:BitmapData;
	private var baselineBits:BitmapData;
	
	public function comparePNG(target:DisplayObject):Boolean 
	{ 
		if (UnitTester.checkEmbeddedFonts)
		{
			if (!checkEmbeddedFonts(target))
			{
				testResult.doFail ("Target " + target + " is using non-embedded or advanced anti-aliased fonts");	
				return true;
			}
		}

		if (!reader.content)
		{
			testResult.doFail ("baseline image not available");
			return true;
		}

		getScreenBits(target);

		try
		{
			baselineBits = new BitmapData(reader.content.width, reader.content.height);
			baselineBits.draw(reader.content, new Matrix());

			var compareVal:Object = baselineBits.compare (screenBits);
		
			if (compareVal is BitmapData && numColorVariances)
				compareVal = compareWithVariances(compareVal as BitmapData)

			if (compareVal != 0)
			{
				testResult.doFail ("compare returned" + compareVal, absolutePathResult(url) + ".bad.png");
					
				if (useRemoteDiffer)
				{
					sendImagesToDiffer();
					return false;
				} else if (fileSuffix != "") { 
					writePNG (target);
				}
			}
		} 
		catch (e:Error) 
		{ 
			testResult.doFail (e.getStackTrace());	
		}
		return true;
	}
	
	private function mergeSandboxBitmap(target:DisplayObject, pt:Point, bm:BitmapData, obj:Object):void
	{
		var targetSize:Point = getTargetSize(target);
		var sbm:BitmapData = new BitmapData(obj.width, obj.height);
		var srcRect:Rectangle = new Rectangle(0, 0, obj.width, obj.height);
		sbm.setPixels(srcRect, obj.bits);
		var targetRect:Rectangle = new Rectangle(pt.x, pt.y, targetSize.x, targetSize.y);
		var sbRect:Rectangle = new Rectangle(obj.x, obj.y, obj.width, obj.height);
		var area:Rectangle = targetRect.intersection(sbRect);
		if (area)
			bm.copyPixels(sbm, srcRect, target.globalToLocal(area.topLeft));
	}

	private function sendImagesToDiffer():void
	{
		UnitTester.callback = stringifyScreen;
	}

	private var ba:ByteArray;
	private function stringifyScreen():void
	{
		ba = screenBits.getPixels(screenBits.rect);
		ba.position = 0;
		connection.send("_ImageDiffer", "startScreenData", screenBits.width, screenBits.height, ba.length, UnitTester.currentTestID, UnitTester.currentScript);
		UnitTester.callback = sendScreen;
	}

	private function sendScreen():void
	{
		if (ba.position + MAX_LC < ba.length)
		{
			connection.send("_ImageDiffer", "addScreenData", stringify(ba));
			UnitTester.callback = sendScreen;
		}
		else
		{
			connection.send("_ImageDiffer", "addScreenData", stringify(ba));
			UnitTester.callback = stringifyBase;
		}
	}

	private function stringifyBase():void
	{
		ba = baselineBits.getPixels(baselineBits.rect);
		ba.position = 0;
		connection.send("_ImageDiffer", "startBaseData", baselineBits.width, baselineBits.height, ba.length);
		UnitTester.callback = sendBase;
	}

	private function sendBase():void
	{
		if (ba.position + MAX_LC < ba.length)
		{
			connection.send("_ImageDiffer", "addBaseData", stringify(ba));
			UnitTester.callback = sendBase;
		}
		else
		{
			connection.send("_ImageDiffer", "addBaseData", stringify(ba));
			connection.send("_ImageDiffer", "compareBitmaps");
		}
	}

	private function stringify(ba:ByteArray):String
	{
		var n:int = Math.min(ba.length - ba.position, MAX_LC);
		var arr:Array = [];
		for (var i:int = 0; i < n; i++)
		{
			var b:int = ba.readUnsignedByte();
			arr.push(b.toString(16))
		}
		return arr.toString();
	}

	private function readCompleteHandler(event:Event):void
	{
		var actualTarget:DisplayObject = DisplayObject(context.stringToObject(target));
		if (comparePNG(actualTarget))
			stepComplete();
	}

	private function readErrorHandler(event:Event):void
	{
		var actualTarget:DisplayObject = DisplayObject(context.stringToObject(target));
		getScreenBits(actualTarget);
		
		baselineMissing = true;
		writePNG(actualTarget);
		// writePNG() creates error handlers which will handle the fail and stepComplete().
	}

	public function readPNG():void
	{
		reader = new Loader();
		var req:URLRequest = new URLRequest();
		if (UnitTester.isApollo) 
		{
			req.url = encodeURI2(CompareBitmap.adjustPath (url));
		} else
                {
                        req.url = url;
                        var base:String = normalizeURL(context.application.url);
                        base = base.substring(0, base.lastIndexOf("/"));
                        while (req.url.indexOf("../") == 0)
                        {
                                base = base.substring(0, base.lastIndexOf("/"));
                                req.url = req.url.substring(3);
                        }

                        req.url = encodeURI2(base + "/" + req.url);
                }
		//	req.url = encodeURI2(url);
		// }
	
		trace ("readPNG:requesting url: " + req.url);
        	reader.contentLoaderInfo.addEventListener(Event.COMPLETE, readCompleteHandler);
        	reader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, readErrorHandler);
        	reader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, readErrorHandler);

		reader.load (req);	
	}


	public static var adjustPath:Function = function(url:String):String { return url; };




    public function getPngByteArray(target:DisplayObject, bitmapData:BitmapData):ByteArray 
	{
		// add png headers
		if (UnitTester.createBitmapReferences)
		{
			var targetSize:Point = getTargetSize(target);
			var stagePt:Point = target.localToGlobal(new Point(0, 0));
            var altPt:Point = target.localToGlobal(targetSize);
            stagePt.x = Math.min(stagePt.x, altPt.x);
            stagePt.y = Math.min(stagePt.y, altPt.y);
			bitmapData = new BitmapData(targetSize.x, targetSize.y);
			bitmapData.draw(target.stage, new Matrix(1, 0, 0, 1, -stagePt.x, -stagePt.y));

		} 
		var png:MustellaPNGEncoder = new MustellaPNGEncoder();
		var ba:ByteArray = png.encode (bitmapData);

		return ba;
	}

	public function writePNG(target:DisplayObject):void 
	{

		var ba:ByteArray = getPngByteArray(target, screenBits);
		trace ("image size: " + ba.length);


		/**
		 * either we got called here to write new baselines
	 	 * or to save a .bad.png for investigation
		 * in addition, with failures, we upload baseline and failure to a server
	 	 */
		if (UnitTester.createBitmapReferences) 
		{	
			fileSuffix = "";
		} 


		writer = new URLLoader();
		var req:URLRequest = new URLRequest();
		req.method = "POST";
		if (UnitTester.isApollo) 
		{ 
			req.url = encodeURI2(UnitTester.bitmapServerPrefix + adjustWriteURI(adjustPath(url))) + fileSuffix;
		} else 
		{
			req.url = encodeURI2(UnitTester.bitmapServerPrefix + absolutePath(url)) + fileSuffix;
		}
		trace ("writing url: " + req.url);
        	writer.addEventListener(Event.COMPLETE, writeCompleteHandler);
        	writer.addEventListener(SecurityErrorEvent.SECURITY_ERROR, writeErrorHandler);
        	writer.addEventListener(IOErrorEvent.IO_ERROR, writeErrorHandler);

		// request data goes on the URL Request
		req.data = ba;
		// can't send this, don't need to anyway var rhArray:Array = new Array(new URLRequestHeader("Content-Length", new String(ba.length) ));
		
		req.contentType = "image/png";
		writer.load (req);	

		/// If this is about creating bitmaps, skip the upload, we're done
		if (UnitTester.createBitmapReferences || UnitTester.run_id == "-1" || baselineMissing)
			return;

		//// Upload
		var writer2:URLLoader = new URLLoader();
		var reqScreen:URLRequest = new URLRequest();

		reqScreen.method = "POST";

		/// we already have the screen data in hand:
		reqScreen.data = ba;

		/// fill in the blanks
		reqScreen.contentType = "image/png";
		reqScreen.url = UnitTester.urlAssemble ("screen", 
			context.testDir, context.scriptName, this.testResult.testID, UnitTester.run_id);

		trace ("upload: " + reqScreen.url);
        	writer2.addEventListener(Event.COMPLETE, uploadCompleteHandler);
        	writer2.addEventListener(SecurityErrorEvent.SECURITY_ERROR, uploadErrorHandler);
        	writer2.addEventListener(IOErrorEvent.IO_ERROR, uploadErrorHandler);
		writer2.load (reqScreen);


		/// get the baseline stuff:
		var writer3:URLLoader = new URLLoader();
		var reqBaseline:URLRequest = new URLRequest();
		/// needed?
		var baBase:ByteArray = getPngByteArray(target, baselineBits);
		
		reqBaseline.data = baBase;
		reqBaseline.contentType = "image/png";
		reqBaseline.method = "POST";
		
		reqBaseline.url = UnitTester.urlAssemble ("baseline", 
			context.testDir, context.scriptName, this.testResult.testID, UnitTester.run_id);

		trace ("upload: " + reqBaseline.url);
        	writer3.addEventListener(Event.COMPLETE, upload2CompleteHandler);
        	writer3.addEventListener(SecurityErrorEvent.SECURITY_ERROR, upload2ErrorHandler);
        	writer3.addEventListener(IOErrorEvent.IO_ERROR, upload2ErrorHandler);
		writer3.load (reqBaseline);


    }

	private function adjustWriteURI(url:String):String
	{
		var pos:int = url.indexOf("file:///");
		if (pos != 0)
		{
			return url;
		}
		url = url.substring(8);
		pos = url.indexOf("|");

		if (pos != 1)
		{
			return url;
		}

		var drive:String = url.substring(0, 1);
		drive = drive.toLowerCase();
		return drive + ":" + url.substring(2);
	}

	private var screenDone:Boolean = false;
	private var baselineDone:Boolean = false;

	private function writeCompleteHandler(event:Event):void
	{
		trace("baseline write successful " + event);
		if( baselineMissing ){
			baselineMissing = false;
			testResult.doFail( baselineMissingMessage );
			stepComplete();
		}else{		
			if (UnitTester.createBitmapReferences)
				stepComplete();
		}
	}

	private function uploadCompleteHandler(event:Event):void
	{
		trace("screen image upload successful " + event);
		screenDone = true;
		checkForStepComplete();
	}

	private function upload2CompleteHandler(event:Event):void
	{
		trace("baseline image upload successful " + event);
		baselineDone = true;
		checkForStepComplete();
	}

	private function writeErrorHandler(event:Event):void
	{
		if( baselineMissing ){
			baselineMissing = false;
			testResult.doFail( baselineMissingMessageFail );
			stepComplete();
		}else{
			testResult.doFail ("error on baseline write: " + event);
			trace("Image baseline write failed " + event);
			if (UnitTester.createBitmapReferences)
				stepComplete();
		}
	}
	private function uploadErrorHandler(event:Event):void
	{
		testResult.doFail ("error on baseline write: " + event);
		trace("Image screen upload failed " + event);
		screenDone = true;
		checkForStepComplete();
	}

	private function upload2ErrorHandler(event:Event):void
	{
		testResult.doFail ("error on baseline write: " + event);
		trace("Image baseline upload failed " + event);
		baselineDone = true;
		checkForStepComplete();
	}

	private function checkForStepComplete():void
	{

		if (baselineDone && screenDone)
			stepComplete();


	}

	/**
	 *  customize string representation
	 */
	override public function toString():String
	{
		var s:String = (UnitTester.createBitmapReferences) ? "CreateBitmap: " : "CompareBitmap";
		if (target)
			s += ": target = " + target;
		if (url)
			s += ", url = " + url;
		return s;
	}

	private function absolutePathResult(url:String):String
	{ 

                var base:String = null;

		if (UnitTester.isApollo) 
		{
                	base = adjustWriteURI(adjustPath (url));
		} else 
		{
                	base = context.application.url;

		}

                base = normalizeURL(base);
		base = base.substring (base.indexOf ("mustella/tests")+14);


		if (!UnitTester.isApollo) 
		{
                	base = base.substring(0, base.lastIndexOf("/"));
		
			var tmp:String = url;

			while (tmp.indexOf("../") == 0)
			{
        			base = base.substring(0, base.lastIndexOf("/"));
        			tmp = tmp.substring(3);
			}

			return base +"/" + tmp;
		} else
		{
			return base;

		}



	}

	private function absolutePathHttp(url:String):String
	{

		if (url.indexOf ("..") == 0)
			return url.substring (3);
		else
			return url;


	}


	
	private function absolutePath(url:String):String
	{
		var swf:String = normalizeURL(root.loaderInfo.url);

		var pos:int = swf.indexOf("file:///");


		if (pos != 0)
		{
		
			var posH:int = swf.indexOf("http://");
			if (posH == 0)
			{
				return absolutePathHttp (url);
			} else
			{

				trace("WARNING: unexpected swf url format, no file:/// at offset 0");
				return url;
			}
		}
		swf = swf.substring(8);
		pos = swf.indexOf("|");
		if (pos != 1)
		{
			trace("WARNING: unexpected swf url format, no | at offset 1 in: " + swf);
			// assume we're on a mac or other unix box, it will do no harm
			return "/" + swf.substring(0, swf.lastIndexOf ("/")+1)  + url;
		}

		var drive:String = swf.substring(0, 1);
		drive = drive.toLowerCase();
		return drive + ":" + swf.substring(2, swf.lastIndexOf("/") + 1) + url;
	}


        public static function normalizeURL(url:String):String
        {
        	var results:Array = url.split("/[[DYNAMIC]]/");
        	return results[0];
        }


	public function keepGoing():void
	{
		trace("keepgoing", url, hasEventListener("stepComplete"));
		stepComplete();
	}

	private function encodeURI2(s:String):String
	{
		var pos:int = s.lastIndexOf("/");
		if (pos != -1)
		{
			var fragment:String = s.substring(pos + 1);
			s = s.substring(0, pos + 1);
			fragment= encodeURIComponent(fragment);
			s = s + fragment;
		}
		return s;
	}

	private function compareWithVariances(bm:BitmapData):Object
	{

		var allowed:int = numColorVariances * UnitTester.pixelToleranceMultiplier;
		var n:int = bm.height;
		var m:int = bm.width;

		for (var i:int = 0; i < n; i++)
		{
			for (var j:int = 0; j < m; j++)
			{
				var pix:int = bm.getPixel(j, i);
				if (pix)
				{
					if(!ignoreMaxColorVariance)
					{
						var red:int = pix >> 16 & 0xff;
						var green:int = pix >> 8 & 0xff;
						var blue:int = pix & 0xff;
						if (red & 0x80)
							red = 256 - red;
						if (blue & 0x80)
							blue = 256 - blue;
						if (green & 0x80)
							green = 256 - green;
						if (red > maxColorVariance ||
							blue > maxColorVariance ||
							green > maxColorVariance)
						{
							return bm;
						}
					}
					allowed--;
					if (allowed < 0)
					{
						return bm;
					}
				}
			}
		}
		return 0;
	}

	private function checkEmbeddedFonts(target:Object):Boolean
	{
		if ("rawChildren" in target)
			target = target.rawChildren;

		if (target is TextField)
		{
			if (target.embedFonts == false)
				return false;
			if (target.antiAliasType == "advanced")
				return false;
			return true;
		}
		else if ("numChildren" in target)
		{
			var n:int = target.numChildren;
			for (var i:int = 0; i < n; i++)
			{
				if (!checkEmbeddedFonts(target.getChildAt(i)))
					return false;
			}
		}
		
		return true;
	}

	override protected function stepComplete():void 
	{ 

                if (baselineBits != null)
                        baselineBits.dispose();
                if (screenBits != null)
                        screenBits.dispose();


		reader=null;
		writer=null;
		
		super.stepComplete();


	}
}

}
