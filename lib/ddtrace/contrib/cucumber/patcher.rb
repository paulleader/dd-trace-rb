require 'ddtrace/contrib/patcher'
require 'ddtrace/ext/integration'
require 'ddtrace/ext/net'
require 'ddtrace/contrib/analytics'

module Datadog
  module Contrib
    module Cucumber
      # Patcher enables patching of 'cucumber' module.
      module Patcher
        include Contrib::Patcher

        module_function

        def target_version
          Integration.version
        end

        def patch
          require 'cucumber'
          require 'ddtrace/pin'

          Datadog::Pin.new(
            Datadog.configuration[:cucumber][:service_name],
            app: Datadog::Contrib::Cucumber::Ext::APP,
            app_type: Datadog::Ext::AppTypes::TEST,
            tracer: -> { Datadog.configuration[:cucumber][:tracer] }
          ).onto(::Cucumber)

          patch_cucumber_runtime
        end

        def patch_cucumber_runtime
          require 'ddtrace/contrib/cucumber/events'

          ::Cucumber::Runtime.class_eval do
            attr_reader :datadog_events

            alias_method :initialize_without_datadog, :initialize
            Datadog::Patcher.without_warnings do
              remove_method :initialize
            end

            def initialize(*args, &block)
              args[0] = ::Cucumber::Configuration.default if args[0].nil?
              @datadog_events = Datadog::Contrib::Cucumber::Events.new(args[0])

              initialize_without_datadog(*args, &block)
            end
          end
        end
      end
    end
  end
end