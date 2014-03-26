module ActionController
  class AuthenticityToken
    LENGTH = 32

    # Note that this will modify +session+ as a side-effect if there is
    # not a master CSRF token already present
    def initialize(session, logger = nil)
      session[:_csrf_token] ||= SecureRandom.base64(LENGTH)
      @master_csrf_token = Base64.strict_decode64(session[:_csrf_token])
      @logger = logger
    end

    def generate_masked
      # Start with some random bits
      one_time_pad = SecureRandom.random_bytes(@master_csrf_token.length)

      # XOR the random bits with the real token and concatenate them
      masked_token = self.class.xor_byte_strings(one_time_pad, @master_csrf_token)

      Base64.strict_encode64(one_time_pad.concat(masked_token))
    end

    def valid?(token)
      return false unless token

      decoded_token = Base64.strict_decode64(token)

      # See if it's actually a masked token or not. In order to
      # deploy this code, we should be able to handle any unmasked
      # tokens that we've issued without error.
      if decoded_token.length == LENGTH
        # This is actually an unmasked token
        if @logger
          @logger.warn "The client is using an unmasked CSRF token. This " +
            "should only happen immediately after you upgrade to masked " +
            "tokens; if this persists, something is wrong."
        end

        self.class.constant_time_equal?(decoded_token, @master_csrf_token)

      elsif decoded_token.length == LENGTH * 2
        # Split the token into the one-time pad and the encrypted
        # value and decrypt it
        one_time_pad = decoded_token.first(LENGTH)
        masked_token = decoded_token.last(LENGTH)
        begin
          csrf_token = self.class.xor_byte_strings(one_time_pad, masked_token)
        rescue ArgumentError
          return false
        end

        self.class.constant_time_equal?(csrf_token, @master_csrf_token)

      else
        # Malformed token of some strange length
        false

      end
    end

    def self.xor_byte_strings(s1, s2)
      if s1.nil? || s2.nil?
        raise ArgumentError, 'Cannot xor nil'
      end

      if s1.length != s2.length
        raise ArgumentError, "Cannot xor strings of different lengths: #{s1.length} and #{s2.length}"
      end

      s1.bytes.zip(s2.bytes).map! { |c1, c2| c1.ord ^ c2.ord }.pack('c*')
    end

    def self.constant_time_equal?(s1, s2)
      return false unless s1.length == s2.length

      result = 0
      s1.chars.to_a.each_index do  |i|
        result |= s1[i].ord ^ s2[i].ord
      end

      result == 0
    end
  end
end
