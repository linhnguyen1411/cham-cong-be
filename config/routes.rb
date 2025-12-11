Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      post '/auth/login', to: 'auth#login'
      resource :settings, only: [:show, :update] 
      resources :work_sessions, only: [:index, :create, :update, :show] do
        collection do
          get :active
        end
      end
      resources :users, only: [:index, :show, :create, :update] do
        member do
          patch :update_password
          post :update_avatar
          get :avatar
        end
      end
      resources :work_shifts, only: [:index, :create, :update, :destroy]
    end
  end
end
