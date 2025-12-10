Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false,
      expose: ['Access-Control-Allow-Private-Network']
  end
end