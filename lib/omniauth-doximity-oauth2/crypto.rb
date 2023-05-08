# frozen_string_literal: true

module OmniAuth
  module DoximityOauth2
    # Static crypto methods
    class Crypto
      class << self
        def create_rsa_key(n, e)
          data_sequence = OpenSSL::ASN1::Sequence([
                                                    OpenSSL::ASN1::Integer(base64_to_long(n)),
                                                    OpenSSL::ASN1::Integer(base64_to_long(e))
                                                  ])
          asn1 = OpenSSL::ASN1::Sequence(data_sequence)
          OpenSSL::PKey::RSA.new(asn1.to_der)
        end

        private

        def base64_to_long(data)
          decoded_with_padding = Base64.urlsafe_decode64(data) + Base64.decode64("==")
          decoded_with_padding.to_s.unpack("C*").map do |byte|
            byte_to_hex(byte)
          end.join.to_i(16)
        end

        def byte_to_hex(int)
          int < 16 ? "0#{int.to_s(16)}" : int.to_s(16)
        end
      end
    end
  end
end
