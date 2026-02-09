require "action_controller/railtie"
require "action_view/railtie"
require "rails/engine"

module Phoenixqueue
  module Web
    class Engine < ::Rails::Engine
      isolate_namespace Phoenixqueue::Web
    end
  end
end

