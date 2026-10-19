# 고정 아바타 카탈로그. DB 레코드와 무관하게 YAML에서 읽는다.
class Avatar
  ATTRIBUTES = %w[handle name gender body_type height_cm top_size bottom_size image source license generator].freeze

  attr_reader(*ATTRIBUTES)

  def initialize(handle, metadata)
    @handle = handle
    (ATTRIBUTES - [ "handle" ]).each do |attribute|
      instance_variable_set("@#{attribute}", metadata.fetch(attribute))
    end
  end

  def self.all
    YAML.safe_load_file(Rails.root.join("config/avatars.yml")).map do |handle, metadata|
      new(handle, metadata)
    end
  end

  # 알 수 없는 handle은 nil을 반환한다.
  def self.find(handle)
    all.find { |avatar| avatar.handle == handle.to_s }
  end
end
