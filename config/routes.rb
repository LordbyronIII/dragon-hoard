DragonHoardRails32::Application.routes.draw do

  namespace :angular_tests do
    get :index
    get :hello_angular
    get :authenticate
    get :items
  end

  namespace :manage do
    resources :customers do
      resources :fingers, controller: 'customers/fingers'
      resources :phones, controller: 'customers/phones'
      resources :addresses, controller: 'customers/addresses'
      resources :alliances, controller: 'customers/alliances' do
        collection do
          get :find
        end
        member do
          get :select
        end
      end
      collection do
        get :find
      end
    end

    resources :orders do
      resources :line_items,  controller: 'orders/line_items' 
      resources :payments,    controller: 'orders/payments'
      resources :users,       controller: 'orders/users' do
        collection do
          post :find
        end
      end
    end

    resources :appraisals

    resources :sales do
      member do
        get :checkout
        get :cancel
      end
    end

    resources :quick_sales do
      member do
        get :checkout
        get :cancel
      end
    end

    resource  :session
    resources :live_searches
  end

  match 'manage' => 'manage#home'

  resources :items
  resources :collections, only: [:index, :show]

  resource  :cart do
    resources :line_items, controller: 'carts/line_items'
  end
  match 'cart/checkout'     => 'carts#checkout',      as: :checkout
  match 'cart/pay'          => 'carts#pay',           as: :pay
  match 'cart/shipping'     => 'carts#shipping',      as: :shipping
  match 'cart/summary'      => 'carts#summary',       as: :summary
  match 'cart/process_cart' => 'carts#process_cart',  as: :process_cart

  resources :users do
    collection do
      get  :forgot_password
      post :generate_new_password
    end

    resources :orders, controller: 'users/orders'
    resources :addresses, controller: 'users/addresses'
    resources :phones, controller: 'users/phones'
    resources :credit_cards, controller: 'users/credit_cards'
  end
  match '/profile' => 'users#profile', as: :profile
  
  resources :orders do
    member do
      get :clear
    end
    
    resources :items, controller: 'orders/items' do
      member do
        get :destroy, as: :delete
      end
    end
  end
  
  match '/policy/delivery' => 'policies#delivery', as: :delivery
  match '/policy/privacy'  => 'policies#privacy',  as: :privacy
  match '/policy/return'   => 'policies#return',   as: :return
  match '/policy/faq'      => 'policies#faq',      as: :faq
  
  match 'about-us' => 'pages#about', as: :about_us
  match 'pages/bad_route' => 'pages#bad_route', as: :bad_route
  
  resource :search, only: [:show]
  resources :colors, only: [:show]
  
  resource :session

  match 'login'   => 'sessions#new',        as: :login
  match 'logout'  => 'sessions#destroy',    as: :logout
  match 'account' => 'users/accounts#show', as: :account
  
  root to: 'pages#home'
  
end
