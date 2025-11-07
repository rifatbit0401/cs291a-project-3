Rails.application.routes.draw do
  get "messages/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  get "/health", to: "health#show"
  #post "/register", to: "users#register"
  post "/auth/register", to: "auth#register"

  post "/auth/login", to: "auth#login"
  
  post "/auth/logout", to: "auth#logout"
  post "/auth/refresh",  to: "auth#refresh"
  get "/auth/me", to: "auth#me"

  # resources :conversations, only: [:index, :create, :show]
  # Conversations & Messages
  resources :conversations, only: [:index, :create, :show] do
    resources :messages, only: [:index]
  end

  resources :messages, only: [:create]
  
  put "/messages/:id/read", to: "messages#mark_as_read"

  get "/expert/queue", to: "expert#queue"
  post "/expert/conversations/:conversation_id/claim", to: "expert#claim"
  post "/expert/conversations/:conversation_id/unclaim", to: "expert#unclaim"

  get "/expert/profile", to: "expert#profile"
  put "/expert/profile", to: "expert#update_profile"
  get "/expert/assignments/history", to: "expert#assignment_history"

  get "/api/conversations/updates", to: "conversations#updates"
  get "/api/messages/updates", to: "messages#updates"
  get "/api/expert-queue/updates", to: "expert#queue_updates"


end
