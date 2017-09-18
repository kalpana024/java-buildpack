# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch NetDiagnostics support.
    class CavNdAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        # download_zip(false, @droplet.sandbox, 'NetDiagnostics Agent')
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        #credentials = @application.services.find_service(FILTER)['credentials']
        java_opts   = @droplet.java_opts
        java_opts.add_javaagent(agent_args)

        #application_name java_opts, credentials
        #tier_name java_opts, credentials
        #node_name java_opts, credentials
        #account_access_key java_opts, credentials
        #account_name java_opts, credentials
        #host_name java_opts, credentials
        #port java_opts, credentials
        #ssl_enabled java_opts, credentials
      end

      def agent_dir
        @droplet.sandbox + 'cav_nd_agent'
      end

      def agent_args
      	ndHome = agent_dir
      	#argument = '#{ndHome}lib/ndmain.jar=time,ndAgentJar=#{ndHome}lib/ndagent-with-dep.jar,ndHome=#{ndHome},tier=default,ndcHost=10.10.40.93,ndcPort=7892,BCILoggingMode=OUTPUT_STREAM'
      	argument = '#{ndHome}lib/ndmain.jar=time'
      	argument
      end

      def supports?
        true
      end

    end
  end
end
