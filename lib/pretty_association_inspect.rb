# -*- coding: utf-8 -*-
require "pretty_association_inspect/version"

# -*- coding: utf-8 -*-
# モデルに関連情報を見やすく表示するメソッドを定義します。
module PrettyAssociationInspect

  extend self
  # 全てのモデルにメソッドを定義する
  def all_models_define
    model_names_array = load_all_models
    model_names_array.each do |model_name|
      klass = eval(model_name)
      pretty_association_inspect_define(klass)
    end
  end

  # 全てのモデルを読み込み、モデル名配列を返す
  def load_all_models
    models_file_path = Dir.glob(Rails.root.join("app/models/*")).grep(/rb\z/)
    models_file_path.each { |m| require(m) }
    return ActiveRecord::Base.subclasses.map(&:name)
  end

  # 表示
  def printed(class_name, model, associations_hash)
    puts "-"*100;
    puts class_name
    puts "[クラスメソッド]"
    delete_pattern = Regexp.new("_(associated|after|before|for|soft)_")
    puts (model.methods(false) - model.instance_methods).delete_if{|name| delete_pattern.match(name) }.sort.join(', ')
    puts "[インスタンスメソッド]"
    puts (model.instance_methods(false) - model.superclass.instance_methods).delete_if{|name| delete_pattern.match(name) }.sort.join(', ')
    puts "[バリデーション]"
    puts model.validators.map{|m| m.class.name.gsub(/ActiveRecord::Validations::|Validator/,"").concat(": #{m.attributes.join(', ')}") }.sort
    puts "[アソシエーション]"
    associations_hash.each { |k, v| puts "%10s  #{v.join(', ')}" % k }
    puts "-"*100
  end

  # 『関連を可愛く表示するメソッド』を定義する
  def pretty_association_inspect_define(klass)
    klass.class_eval do |model|
      self.define_singleton_method(:to){
        associations_hash = model.reflect_on_all_associations.each_with_object({}) do |m, hash|
          name = m.class.class_name.gsub("Reflection", "")
          hash[name] ||= []
          hash[name] << m.name
        end
        PrettyAssociationInspect.printed(klass.name, model, associations_hash)
        return self.last || self
      }
    end

    klass.class_eval do |model|
      define_method(:to){
        associations_hash = model.reflect_on_all_associations.each_with_object({}) do |m, hash|
          hash[m.class.class_name] ||= []
          hash[m.class.class_name] << m.name
        end
        PrettyAssociationInspect.printed(klass.name, model, associations_hash)
        return self
      }
    end
  end
end

PrettyAssociationInspect.all_models_define
