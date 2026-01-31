Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "home#index"

  # Products & Reviews
  resources :products do
    resources :reviews, only: [ :create ]
  end

  # Snaps (Style Feed)
  resources :snaps, only: [ :index, :new, :create, :show ]

  # Search
  get "search", to: "search#index"

  # Inventory Management (Epic 2)
  namespace :inventory do
    get :scan
    get :stock_in
    post :stock_in, action: :create_stock_in
    get :stock_out
    post :stock_out, action: :create_stock_out
    get :history
    post :find_variant
  end

  # Dashboard (Epic 4.3 - 익명 CRM 대시보드)
  namespace :dashboard do
    get :index
    get :regional_trends
    get :preference_analysis
  end

  # Epic 8: 거래처 및 발주 관리
  resources :suppliers
  resources :purchase_orders do
    member do
      post :submit # 발주서 제출
      post :receive # 입고 처리
    end
  end

  # 거래처 확인 URL (토큰 기반)
  get "po/confirm/:token", to: "purchase_orders#confirm", as: :confirm_purchase_order
  post "po/confirm/:token", to: "purchase_orders#confirm"

  # Epic 7: UCP API
  namespace :api do
    namespace :v1 do
      get "ucp/products", to: "ucp#products"
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA Support (Progressive Web App)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
