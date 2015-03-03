module Sources
  class DigitalOcean < Source
    class << self
      def required_fields
        {
          username: :string,
          password: :password,
          image_name: :string
        }
      end
    end
    Source.source_types << self
  end
end
