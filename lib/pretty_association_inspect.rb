# -*- coding: utf-8 -*-
# モデルに関連情報を見やすく表示するメソッドを定義します。
module PrettyAssociationInspect
  extend self

  # 『関連を可愛く表示するメソッド』を定義する
  def pretty_association_inspect_define(klass)
    klass.class_eval do |model|
      self.define_singleton_method(:to){
        associations_hash = PrettyAssociationInspect.build_association_hash(model)
        PrettyAssociationInspect.printed(klass, model, associations_hash)
        return self.last
      }

      define_method(:to){
        associations_hash = PrettyAssociationInspect.build_association_hash(model)
        PrettyAssociationInspect.printed(klass, model, associations_hash)
        return self
      }
    end
  end

  # アソシエーションをハッシュに変換
  def build_association_hash(model)
    model.reflect_on_all_associations.each_with_object({}) do |m, hash|
      name = m.class.class_name.gsub("Reflection", "")
      hash[name] ||= []
      human_name = PrettyAssociationInspect.jp_scripe(m.klass.model_name.human)
      hash[name] << {
        association: m.name,
        human: human_name,
        model_name: m.active_record.name
      }
    end
  end

  # バリューを整形
  def value_convert(k, v, klass)
    klass.class_eval {
      is_e  = Object.const_defined?(:Enumerize) && first.send(k).kind_of?(Enumerize::Value)
      return "#{v} #{first.send(k).text} #{send(k).values} #{send(k).values.map(&:text)}" if is_e
      return v.strftime("%y年%m月%d日 %H:%M") if v.respond_to?(:strftime)
      return columns_hash[k.to_s].type if v.blank?
    }
  end

  # 表示
  def printed(klass, model, associations_hash)
    pretty_associations_array = []
    klass.class_eval{|klass|
      klass.first.attributes.each{|k ,v|
        column = "%20s" % k
        value  = PrettyAssociationInspect.value_convert(k, v, klass)
        jp_val = PrettyAssociationInspect.jp_scripe(klass.human_attribute_name(k))
        db_val = "%5s"  % v
        pretty_associations_array <<  "#{column} #{jp_val} #{db_val}"
      }
    }
    puts "-"*100;
    puts klass.name + "#{jp_scripe(klass.model_name.human)}"
    puts "[クラスメソッド]"
    base_pattern   = "(before|after|around)_(add|remove|restore)|_associated_records_for_|inherited"
    extr_pattern   = "attribute_type_decorations|soft_de|_restore_callback|indexed_|_by_resource"
    delete_pattern = Regexp.new( [ base_pattern, extr_pattern ].join('|') )
    class_m  = model.methods(false) - model.instance_methods
    puts (class_m).delete_if{|name|
      delete_pattern.match(name) }.sort.join(', ')
    puts "[インスタンスメソッド]"
    instance_m = model.instance_methods(false) - model.superclass.instance_methods
    puts (instance_m).delete_if{|name|
      delete_pattern.match(name) }.sort.join(', ')
    puts "[バリデーション]"
    puts model.validators.map{|m|
      m.class.name.gsub(/Active|Record|Validations|Model|Validator/,"")
        .concat(": #{m.attributes.join(', ')} #{m.options}") }.sort
    puts "[アソシエーション]"
    associations_hash.each do |k, v|
      puts "%10s"%k + "  " + v.map{ |m| [m[:association], m[:human]].join }.join(', ')
    end
    puts "[詳細]"
    puts pretty_associations_array
    puts "-"*100
  end

  # 日本語だけ抽出
  def jp_scripe(str)
    japanese = Regexp.new(/[亜-熙ぁ-んァ-ヶ]/)
    "(#{str})" if japanese =~ str
  end

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

end
