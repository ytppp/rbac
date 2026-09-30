# 所有模型的「公共父类」。
# Rails 的约定：app/models 目录下的模型都继承 ApplicationRecord，
# 这里再统一继承 ActiveRecord::Base —— 也就是 Rails 的 ORM 基类，
# 负责把 Ruby 对象和数据库表对应起来。
#
# 命名约定（Rails 自动推导，不用手写表名）：
#   类名 User        -> 表名 users        （转成复数 + 小写下划线）
#   类名 UserRole    -> 表名 user_roles
#   类名 Note        -> 表名 notes
class ApplicationRecord < ActiveRecord::Base
  # 声明自己是抽象基类：它本身不对应任何一张表，只被别的模型继承
  primary_abstract_class
end
