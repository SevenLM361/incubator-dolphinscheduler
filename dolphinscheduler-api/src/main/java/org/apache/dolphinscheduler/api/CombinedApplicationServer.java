/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.dolphinscheduler.api;

import org.apache.dolphinscheduler.alert.AlertServer;
import org.apache.dolphinscheduler.dao.AlertDao;
import org.apache.dolphinscheduler.dao.ProcessDao;
import org.apache.dolphinscheduler.server.master.MasterServer;
import org.apache.dolphinscheduler.server.rpc.LoggerServer;
import org.apache.dolphinscheduler.server.worker.WorkerServer;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.ServletComponentScan;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.ComponentScan;
import springfox.documentation.swagger2.annotations.EnableSwagger2;

@SpringBootApplication
@ServletComponentScan
@ComponentScan("cn.escheduler")
@EnableSwagger2
public class CombinedApplicationServer extends SpringBootServletInitializer {

    public static void main(String[] args) throws Exception {

        ConfigurableApplicationContext context = SpringApplication.run(ApiApplicationServer.class, args);
        ProcessDao processDao = context.getBean(ProcessDao.class);
        AlertDao alertDao = context.getBean(AlertDao.class);

        MasterServer master = new MasterServer(processDao);
        master.run(processDao);

        WorkerServer workerServer = new WorkerServer(processDao, alertDao);
        workerServer.run(processDao, alertDao);

        LoggerServer server = new LoggerServer();
        server.start();

        AlertServer alertServer = AlertServer.getInstance();
        alertServer.start();
    }
}