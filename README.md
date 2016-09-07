# PrettyAssociationInspect
モデルで定義されたメソッド、関連、バリデーションを
コンソール上で美しく表示します。

## Installation

```ruby
gem 'pretty_association_inspect'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pretty_association_inspect

## Usage

### メソッド、関連、バリデーションを表示する

```rb
User.to
```

### 関連を、４モデル先まで表示する(デフォルトは１モデル先)

```rb
User.toto 4
```

### カラムのカラムの部分一致検索

```rb
User.s "小野寺"
```

### カラムのカラムの完全一致検索

```rb
User.ss "小野寺"
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
