Dummy::Application.routes.draw do
  mount Phoenixqueue::Web::Engine => "/phoenixqueue"
end

