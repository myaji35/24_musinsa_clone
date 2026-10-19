require "test_helper"

class AvatarsPickerTest < ActionView::TestCase
  test "renders ten labeled radio cards with served thumbnails and metadata" do
    render partial: "avatars/picker", locals: { name: "product[avatar_handle]", selected: "KangUNA" }

    assert_select "fieldset legend", text: "아바타 선택"
    assert_select 'input[type=radio][name="product[avatar_handle]"]', count: 10
    assert_select "input[type=radio][checked]", count: 1
    assert_select 'input[value="KangUNA"][checked]'
    assert_select "label", count: 10
    assert_select "span", text: "AI 가상인물", count: 10
    Avatar.all.each do |avatar|
      assert_select "label" do |labels|
        card = labels.find { |label| label.at_css("input")["value"] == avatar.handle }
        assert_includes card.text, avatar.name
        assert_includes card.text, avatar.body_type
        assert_includes card.text, "#{avatar.height_cm}cm · 상의 #{avatar.top_size} · 하의 #{avatar.bottom_size}"
        assert_match %r{/assets/avatars/#{avatar.handle}-card(?:-[a-f0-9]+)?\.jpg}, card.at_css("img")["src"]
      end
    end
  end
end
