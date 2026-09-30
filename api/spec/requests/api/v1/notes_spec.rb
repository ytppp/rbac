require "rails_helper"

RSpec.describe "内容接口（app 模块）", type: :request do
  let!(:outfit) do
    create(:note, title: "夏日清爽穿搭", channel: "穿搭", author_name: "穿搭日记", sort: 1)
  end
  let!(:coffee) do
    create(:note, title: "自制生椰拿铁", channel: "美食", author_name: "咖啡因依赖", sort: 2)
  end

  it "不需要登录即可访问" do
    get "/api/v1/notes"

    expect(response).to have_http_status(:ok)
    expect(json_body["items"].size).to eq(2)
  end

  it "返回前端渲染所需的字段" do
    get "/api/v1/notes"

    expect(json_body["items"].first.keys).to match_array(
      %w[id title cover cover_ratio author avatar_color likes channel]
    )
  end

  it "频道列表以虚拟频道「推荐」开头，其余按内容顺序" do
    get "/api/v1/notes"

    expect(json_body["channels"]).to eq([Note::ALL_CHANNEL, "穿搭", "美食"])
  end

  it "按频道过滤" do
    get "/api/v1/notes", params: { channel: "美食" }

    expect(json_body["items"].map { |item| item["title"] }).to eq(["自制生椰拿铁"])
  end

  it "频道为「推荐」时不过滤" do
    get "/api/v1/notes", params: { channel: Note::ALL_CHANNEL }

    expect(json_body["items"].size).to eq(2)
  end

  it "关键词可命中标题、作者与频道" do
    get "/api/v1/notes", params: { keyword: "咖啡因" }
    expect(json_body["items"].map { |item| item["title"] }).to eq(["自制生椰拿铁"])

    get "/api/v1/notes", params: { keyword: "穿搭" }
    expect(json_body["items"].map { |item| item["title"] }).to include("夏日清爽穿搭")

    get "/api/v1/notes", params: { keyword: "拿铁" }
    expect(json_body["items"].map { |item| item["title"] }).to eq(["自制生椰拿铁"])
  end

  it "无匹配时返回空列表" do
    get "/api/v1/notes", params: { keyword: "不存在的关键词" }

    expect(response).to have_http_status(:ok)
    expect(json_body["items"]).to be_empty
    expect(json_body["meta"]["total"]).to eq(0)
  end

  it "按 sort 升序返回" do
    get "/api/v1/notes"

    expect(json_body["items"].map { |item| item["title"] }).to eq(["夏日清爽穿搭", "自制生椰拿铁"])
  end
end
