require "openssl"
require "base64"
require "digest"

module Wechat
  class Protocol
    class Invalid < StandardError
      def initialize = super("Invalid WeChat payload")
    end

    def self.verify!(signature:, timestamp:, nonce:, encrypted: nil)
      raise Invalid if Config.token.blank? || timestamp.blank? || nonce.blank?
      expected = Digest::SHA1.hexdigest([Config.token, timestamp, nonce, encrypted].compact.sort.join)
      raise Invalid unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
    end

    def self.parse(xml)
      raise Invalid if xml.bytesize > 1.megabyte || xml.match?(/<!DOCTYPE|<!ENTITY/i)
      doc = Nokogiri::XML(xml) { |options| options.strict.nonet }
      raise Invalid unless doc.root&.name == "xml"
      doc.root.element_children.to_h { |node| [node.name, node.text] }
    rescue Nokogiri::XML::SyntaxError
      raise Invalid
    end

    def self.decrypt(encrypted)
      key = Base64.strict_decode64(Config.encoding_aes_key + "=")
      raise Invalid unless key.bytesize == 32 && Config.app_id.present?
      cipher = OpenSSL::Cipher.new("AES-256-CBC")
      cipher.decrypt
      cipher.padding = 0
      cipher.key = key
      cipher.iv = key.byteslice(0, 16)
      raw = cipher.update(Base64.strict_decode64(encrypted)) + cipher.final
      padding = raw.getbyte(-1)
      raise Invalid unless raw.bytesize % 32 == 0 && padding && padding.between?(1, 32) && raw.end_with?(padding.chr * padding)
      raw = raw.byteslice(0, raw.bytesize - padding)
      raise Invalid if raw.bytesize < 20
      length = raw.byteslice(16, 4).unpack1("N")
      raise Invalid if length > raw.bytesize - 20
      raise Invalid unless raw.byteslice(20 + length..) == Config.app_id
      raw.byteslice(20, length).force_encoding(Encoding::UTF_8)
    rescue ArgumentError, OpenSSL::Cipher::CipherError
      raise Invalid
    end
  end
end
