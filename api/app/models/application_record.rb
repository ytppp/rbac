# 所有模型的公共父类。
class ApplicationRecord < ActiveRecord::Base
  # 抽象基类，本身不映射任何表
  primary_abstract_class
end
