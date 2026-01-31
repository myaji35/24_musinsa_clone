# Bullet configuration for N+1 query detection
if defined?(Bullet)
  Bullet.enable = true

  # Development environment settings
  if Rails.env.development?
    Bullet.alert = false             # JavaScript alert in browser (DISABLED)
    Bullet.bullet_logger = true      # Log to log/bullet.log
    Bullet.console = true            # Log to browser console
    Bullet.rails_logger = true       # Log to Rails log
    Bullet.add_footer = false        # Add footer with query warnings (DISABLED)
  end

  # Test environment settings
  if Rails.env.test?
    Bullet.bullet_logger = true
    Bullet.raise = true              # Raise error on N+1 queries in tests
  end

  # Detection settings
  Bullet.n_plus_one_query_enable = true        # Detect N+1 queries
  Bullet.unused_eager_loading_enable = true    # Detect unused eager loading
  Bullet.counter_cache_enable = true           # Suggest counter cache

  # Whitelist (add paths to ignore)
  # Bullet.add_whitelist type: :n_plus_one_query, class_name: "Product", association: :variants
end
