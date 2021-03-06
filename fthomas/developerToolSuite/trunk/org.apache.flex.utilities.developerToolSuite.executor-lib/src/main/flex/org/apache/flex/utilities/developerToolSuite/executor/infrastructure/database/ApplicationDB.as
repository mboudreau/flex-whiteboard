/**
 Licensed to the Apache Software Foundation (ASF) under one or more
 contributor license agreements.  See the NOTICE file distributed with
 this work for additional information regarding copyright ownership.
 The ASF licenses this file to You under the Apache License, Version 2.0
 (the "License"); you may not use this file except in compliance with
 the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
package org.apache.flex.utilities.developerToolSuite.executor.infrastructure.database {
    import flash.data.SQLConnection;
    import flash.data.SQLStatement;
    import flash.events.SQLErrorEvent;
    import flash.events.SQLEvent;
    import flash.filesystem.File;
    import flash.net.Responder;

    import mx.logging.ILogger;
    import mx.utils.ObjectUtil;

    import org.apache.flex.utilities.developerToolSuite.executor.infrastructure.util.LogUtil;

    public class ApplicationDB {

        private static var LOG:ILogger = LogUtil.getLogger(ApplicationDB);

        public static const DATABASE_NAME:String = "DTSDB.db";
        private static var _conn:SQLConnection;

        public var DBReady:Boolean;

        public function ApplicationDB() {
        }

        public function connect():void {
            if (DBReady) {
                return;
            }

            LOG.debug("Connecting async DB: " + ApplicationDB.DATABASE_NAME);
            _conn = new SQLConnection();

            _conn.addEventListener(SQLEvent.OPEN, openHandler);
            _conn.addEventListener(SQLErrorEvent.ERROR, errorHandler);

            // The database file is in the application storage directory
            var folder:File = File.applicationStorageDirectory;
            var dbFile:File = folder.resolvePath(DATABASE_NAME);

            _conn.openAsync(dbFile);
        }

        public function close():void {
            LOG.debug("Closing async DB: " + ApplicationDB.DATABASE_NAME);
            _conn.close();
            DBReady = false;
        }

        private function openHandler(event:SQLEvent):void {
            DBReady = true;
            LOG.debug("the database was opened successfully");
        }

        private function errorHandler(event:SQLErrorEvent):void {
            LOG.error("Error while opening the DB: " + ObjectUtil.toString(event.error));
        }

        public function executeSqlStatement(stmt:SQLStatement, responder:Responder):void {
            stmt.sqlConnection = _conn;
            stmt.execute(-1, responder);
        }
    }
}
