namespace :characters do
  desc "캐릭터 정본을 데이터베이스에 동기화"
  task sync: :environment do
    YAML.load_file(Rails.root.join("config/characters.yml")).each do |attributes|
      Character.find_or_initialize_by(handle: attributes.fetch("handle")).update!(attributes)
    end
  end
end
