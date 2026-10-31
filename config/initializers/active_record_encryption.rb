# Configure before Active Record consumes its encryption configuration.
Rails.application.config.active_record.encryption.tap do |encryption|
  %i[primary_key deterministic_key key_derivation_salt].each do |name|
    encryption.public_send(
      "#{name}=",
      Rails.application.credentials.dig(:active_record_encryption, name).presence ||
        Rails.application.key_generator.generate_key("active_record_encryption/#{name}", 32).unpack1("H*")
    )
  end
end
