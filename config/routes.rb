Phoenixqueue::Web::Engine.routes.draw do
  root to: "dashboard#show"

  resources :jobs, only: [:index, :show] do
    post :retry, on: :member
    post :resume, on: :member
    post :cancel, on: :member
  end
end

