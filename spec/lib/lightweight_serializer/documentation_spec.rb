require 'rails_helper'
require './lib/lightweight_serializer'

RSpec.describe LightweightSerializer::Documentation do
  before do
    user_model = Struct.new(:name, :email)

    serializer_for_model = Class.new(LightweightSerializer::Serializer) do
      serializes model: user_model

      attribute :name,
                description: 'Name of the user',
                nullable:    false,
                type:        :string

      attribute :email,
                description: 'Email of the user',
                nullable:    true,
                type:        :string
    end

    serializer_without_type = Class.new(LightweightSerializer::Serializer) do
      no_automatic_type_field!

      attribute :unnested_attribute,
                type: :string

      group :details do
        attribute :attr1, type: :string
        attribute :attr2, type: :integer

        nested :user,
               serializer:  serializer_for_model,
               description: 'Some User',
               minimum:     2
      end
    end

    test_serializer_with_type = Class.new(LightweightSerializer::Serializer) do
      serializes type: :my_cool_type

      attribute :attr,
                description: 'Test description',
                type:        :string,
                enum:        [:foo, :bar, :baz]

      attribute :other_attr,
                illegal_documentation_key: 'this should not be in the docs'

      attribute :date,
                type: :datetime

      attribute :attr_without_documentation

      collection :users,
                 type:                      'some weird type',
                 illegal_documentation_key: 'this should not be in the docs',
                 serializer:                serializer_for_model,
                 description:               'List of users',
                 minimum:                   2

      nested :nested_nullable,
             description:               'Some nested thing',
             serializer:                serializer_without_type,
             type:                      'some weird type',
             illegal_documentation_key: 'this should not be in the docs',
             nullable:                  true

      nested :nested_not_nullable,
             description:               'Some nested thing',
             type:                      'some weird type',
             illegal_documentation_key: 'this should not be in the docs',
             serializer:                serializer_without_type
    end

    stub_const('TestSerializer::TestUser', user_model)
    stub_const('TestSerializer::SerializerForModel', serializer_for_model)
    stub_const('TestSerializer::SerializerWithoutType', serializer_without_type)
    stub_const('TestSerializerWithType', test_serializer_with_type)
  end

  describe '.identifier_for' do
    it 'generates identifiers based on the serializer class name' do
      expect(described_class.identifier_for(TestSerializerWithType)).to eq('test_with_type')
      expect(described_class.identifier_for(TestSerializer::SerializerForModel)).to eq('test--for_model')
      expect(described_class.identifier_for(TestSerializer::SerializerWithoutType)).to eq('test--without_type')
    end
  end

  describe '#identifier' do
    it 'returns the identifier of the passed in class' do
      documentation = described_class.new(TestSerializerWithType)
      expect(documentation.identifier).to eq(described_class.identifier_for(TestSerializerWithType))
    end
  end

  describe '#openapi_schema' do
    let(:serializer) { TestSerializerWithType }
    subject { described_class.new(serializer).openapi_schema }

    describe 'general object structure' do
      it 'generates an object as the base element' do
        expect(subject).to be_kind_of(Hash)
        expect(subject.keys).to match_array([:type, :properties])
      end

      it 'generates an entry in the properties hash for each defined attribute' do
        expect(subject[:properties].keys).to include(:attr, :date, :attr_without_documentation)
      end

      it 'generates an entry for each nested and collection serializers' do
        expect(subject[:properties].keys).to include(:users, :nested_nullable)
      end

      context 'when grouping is used' do
        let(:serializer) { TestSerializer::SerializerWithoutType }

        it 'generates an undescribed object for the group' do
          expect(subject[:properties].keys).to match_array([:unnested_attribute, :details])
          expect(subject[:properties][:details][:type]).to eq('object')
          expect(subject[:properties][:details][:properties].keys).to match_array([:attr1, :attr2, :user])
        end
      end
    end

    describe 'type field generation' do
      context 'when a serialized type is provided' do
        let(:serializer) do
          Class.new(LightweightSerializer::Serializer) { serializes type: :my_cool_type }
        end

        it 'adds a type field' do
          expect(subject[:properties].keys).to include(:type)
        end

        it 'adds a string field with description, example and forces type value' do
          expect(subject[:properties][:type][:type]).to eq(:string)
          expect(subject[:properties][:type][:description]).to eq(described_class::TYPE_FIELD_DESCRIPTION)
          expect(subject[:properties][:type][:enum]).to eq([:my_cool_type])
          expect(subject[:properties][:type][:example]).to eq(:my_cool_type)
        end
      end

      context 'when a serialized model is provided by a class' do
        let(:serializer) do
          Class.new(LightweightSerializer::Serializer) { serializes model: TestSerializer::TestUser }
        end

        it 'adds a type field' do
          expect(subject[:properties].keys).to include(:type)
        end

        it 'adds a string field with description, example and forces type based on model' do
          expect(subject[:properties][:type].keys).to match_array([:type, :description, :enum, :example])

          expect(subject[:properties][:type][:type]).to eq(:string)
          expect(subject[:properties][:type][:description]).to eq(described_class::TYPE_FIELD_DESCRIPTION)
          expect(subject[:properties][:type][:enum]).to eq([TestSerializer::TestUser.name.underscore])
          expect(subject[:properties][:type][:example]).to eq(TestSerializer::TestUser.name.underscore)
        end
      end

      context 'when a serialized model is provided as a string' do
        let(:serializer) do
          Class.new(LightweightSerializer::Serializer) { serializes model: 'TestSerializer::TestUser' }
        end

        it 'adds a type field' do
          expect(subject[:properties].keys).to include(:type)
        end

        it 'adds a string field with description, example and forces type based on model' do
          expect(subject[:properties][:type].keys).to match_array([:type, :description, :enum, :example])

          expect(subject[:properties][:type][:type]).to eq(:string)
          expect(subject[:properties][:type][:description]).to eq(described_class::TYPE_FIELD_DESCRIPTION)
          expect(subject[:properties][:type][:enum]).to eq(['TestSerializer::TestUser'.underscore])
          expect(subject[:properties][:type][:example]).to eq('TestSerializer::TestUser'.underscore)
        end
      end

      context 'when no information about serialized type is given' do
        let(:serializer) do
          Class.new(LightweightSerializer::Serializer) {}
        end

        it 'adds a type field' do
          expect(subject[:properties].keys).to include(:type)
        end

        it 'adds a string field with description, example and forces type based on model' do
          expect(subject[:properties][:type].keys).to match_array([:type, :description])

          expect(subject[:properties][:type][:type]).to eq(:string)
          expect(subject[:properties][:type][:description]).to eq(described_class::TYPE_FIELD_DESCRIPTION)
        end
      end

      context 'when type field is explicitly skipped' do
        let(:serializer) do
          Class.new(LightweightSerializer::Serializer) { no_automatic_type_field! }
        end

        it 'does not add a type field' do
          expect(subject[:properties].keys).not_to include(:type)
        end
      end
    end

    describe 'generic attributes' do
      it 'puts all documentation params into the documentation' do
        expect(subject[:properties][:attr][:description]).to eq('Test description')
        expect(subject[:properties][:attr][:type]).to eq(:string)
        expect(subject[:properties][:attr][:enum]).to eq([:foo, :bar, :baz])
      end

      it 'filters out unknown keys' do
        expect(subject[:properties][:other_attr].keys).not_to include(:illegal_documentation_key)
      end

      context 'when an attribute does not have any documentation params' do
        it 'adds an empty hash' do
          expect(subject[:properties][:attr_without_documentation]).to be_kind_of(Hash)
          expect(subject[:properties][:attr_without_documentation]).to be_blank
        end
      end
    end

    describe 'collections' do
      it 'puts all documentation params into the documentation' do
        expect(subject[:properties][:users][:description]).to eq('List of users')
        expect(subject[:properties][:users][:minimum]).to eq(2)
      end

      it 'does not include `serializer` or any illegal attributes as documentation attributes' do
        expect(subject[:properties][:users].keys).not_to include(:serializer)
        expect(subject[:properties][:users].keys).not_to include(:illegal_documentation_key)
      end

      it 'overrides the type' do
        expect(subject[:properties][:users][:type]).to eq(:array)
      end

      it 'generates a reference to the given serializer for the items' do
        expect(subject[:properties][:users][:items][:$ref]).to eq('#/components/schemas/test--for_model')
      end
    end

    describe 'nested nullable' do
      it 'puts all documentation params into the documentation' do
        expect(subject[:properties][:nested_nullable][:description]).to eq('Some nested thing')
        expect(subject[:properties][:nested_nullable][:nullable]).to eq(true)
      end

      it 'does not include `serializer` or any illegal attributes as documentation attributes' do
        expect(subject[:properties][:nested_nullable].keys).not_to include(:serializer)
        expect(subject[:properties][:nested_nullable].keys).not_to include(:illegal_documentation_key)
      end

      it 'removes the type' do
        expect(subject[:properties][:nested_nullable].keys).not_to include(:type)
      end

      it 'generates a oneOf-array with reference and null' do
        expect(subject[:properties][:nested_nullable][:oneOf]).to be_kind_of(Array)
        expect(subject[:properties][:nested_nullable][:oneOf].first[:$ref]).to eq('#/components/schemas/test--without_type')
        expect(subject[:properties][:nested_nullable][:oneOf].second[:type]).to eq(:null)
      end
    end

    describe 'nested not nullable' do
      it 'puts all documentation params into the documentation' do
        expect(subject[:properties][:nested_not_nullable][:description]).to eq('Some nested thing')
      end

      it 'does not include `serializer` or any illegal attributes as documentation attributes' do
        expect(subject[:properties][:nested_not_nullable].keys).not_to include(:serializer)
        expect(subject[:properties][:nested_not_nullable].keys).not_to include(:illegal_documentation_key)
      end

      it 'removes the type' do
        expect(subject[:properties][:nested_not_nullable].keys).not_to include(:type)
      end

      it 'generates an allOf-array with reference' do
        expect(subject[:properties][:nested_not_nullable][:allOf]).to be_kind_of(Array)
        expect(subject[:properties][:nested_not_nullable][:allOf].first[:$ref]).to eq('#/components/schemas/test--without_type')
      end
    end

    describe 'special behaviors' do
      describe 'when a nullable field uses an enum' do
        let(:serializer) do
          Class.new(LightweightSerializer::Serializer) do
            attribute :nullable_with_enum,
                      nullable: true,
                      enum:     [:foo, :bar, :baz]
          end
        end

        it 'adds `nil` as a possible value' do
          expect(subject[:properties][:nullable_with_enum][:nullable]).to eq(true)
          expect(subject[:properties][:nullable_with_enum][:enum]).to match_array([:foo, :bar, :baz, nil])
        end
      end
    end
  end
end
