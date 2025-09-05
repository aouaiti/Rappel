RedmineApp::Application.routes.draw do
  resources :projects do
    resources :rappels
  end
end 