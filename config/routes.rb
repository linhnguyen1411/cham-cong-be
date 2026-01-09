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
      resources :roles, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :assign_permissions
        end
      end
      resources :permissions, only: [:index, :show]
      resource :settings, only: [:show, :update]
      resources :forgot_checkin_requests, only: [:index, :show, :create] do
        collection do
          get :my_requests
          get :pending
        end
        member do
          post :approve
          post :reject
        end
      end 
      resources :work_sessions, only: [:index, :create, :update, :show] do
        collection do
          get :active
          post :process_forgot_checkouts
        end
      end
      resources :users, only: [:index, :show, :create, :update] do
        member do
          patch :update_password
          post :update_avatar
          get :avatar
          patch :deactivate
        end
      end
      resources :work_shifts, only: [:index, :create, :update, :destroy]
      resources :branches, only: [:index, :show, :create, :update, :destroy]
      resources :departments, only: [:index, :show, :create, :update, :destroy]
      resources :positions, only: [:index, :show, :create, :update, :destroy]
      resources :shift_registrations, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :my_registrations
          get :available_shifts
          get :pending
          post :bulk_create
          post :bulk_approve
          post :admin_bulk_update
          post :admin_quick_add
          post :admin_quick_delete
        end
        member do
          post :approve
          post :reject
          post :admin_update
        end
      end
    end
  end
end
