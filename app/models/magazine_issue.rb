# 매거진 호(config/magazine/issue-NN.yml). 초안(draft)은 관리자 미리보기로만 보인다.
class MagazineIssue
  DIR = Rails.root.join("config/magazine")

  attr_reader :data

  def self.all
    Dir[DIR.join("issue-*.yml")].sort.reverse.map { |path| new(YAML.safe_load_file(path)) }
  end

  def self.visible(admin:)
    all.select { |issue| admin || issue.published? }
  end

  def initialize(data)
    @data = data
  end

  def number = data["issue"]
  def title = data["title"]
  def subtitle = data["subtitle"]
  def cover = data["cover"] || {}
  def published? = data["status"] == "published"
  def articles = Array(data["articles"])

  def article(slug)
    articles.find { |article| article["slug"] == slug }
  end

  # 기사에 나오는 상품(공개 상품만, 관리자는 초안 포함)
  def products(ids, admin:)
    scope = Product.where(supplier_product_code: Array(ids).map { |id| "JIEUM-#{id}" }).includes(:variants, :reviews, :worn_character)
    scope = scope.published unless admin
    by_code = scope.index_by(&:catalog_id)
    Array(ids).filter_map { |id| by_code[id] }
  end
end
