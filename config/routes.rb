Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "home#index"

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resource :cart, only: [ :show ]
  resources :cart_items, only: [ :create, :update, :destroy ]
  resource :checkout, only: [ :new, :create ]
  get "orders/lookup", to: "customer_orders#lookup", as: :orders_lookup
  post "orders/lookup", to: "customer_orders#verify"
  get "orders/:checkout_number", to: "customer_orders#show", as: :customer_order

  # Products & Reviews
  resources :products do
    resources :reviews, only: [ :create ]
    resource :cutout, only: [ :show, :create, :update ], controller: "product_cutouts"
  end

  # Snaps (Style Feed)
  resources :snaps, only: [ :index, :show ]

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
  get "dashboard", to: redirect { |_params, request|
    query = request.query_string
    query.empty? ? "/dashboard/index" : "/dashboard/index?#{query}"
  }
  namespace :dashboard do
    get :index
    get :regional_trends
    get :preference_analysis
  end

  # Epic 8: 거래처 및 발주 관리
  resources :suppliers
  resources :supplier_imports, only: [ :index, :new, :create, :show ] do
    member { post :retry }
  end
  resources :product_analyses, only: [ :index, :show, :create, :update ] do
    collection { post :analyze_pending }
  end
  resources :trends, only: [ :index, :create ]
  get "kpi", to: "kpi#index", as: :kpi
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
