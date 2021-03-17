require 'rails_helper'
require './lib/lightweight_serializer'

RSpec.describe LightweightSerializer::Serializer do
  before do
    address_serializer_class = Class.new(LightweightSerializer::Serializer) do
      serializes type: :address

      allow_options :look_up_zip_for_city

      attribute(:address_type)
      attribute(:street)
      attribute(:number)
      attribute(:city) { |object| object.city.upcase }
    end

    error_serializer_class = Class.new(LightweightSerializer::Serializer) do
      no_root!
      attribute :message
    end

    error_serializer_with_private_method_class = Class.new(LightweightSerializer::Serializer) do
      attribute :message
      attribute(:translated_message) { |object| translate(object.message) }

      private

      def translate(message)
        message.reverse
      end
    end

    drink_serializer_class = Class.new(LightweightSerializer::Serializer) do
      serializes type: :drink

      attribute :brand
      attribute :name
      attribute :serving_size, condition: :show_serving_size
    end

    heated_drink_serializer_class = Class.new(drink_serializer_class) do
      attribute :optimal_drinking_temperature
    end

    unbranded_drink_serializer_class = Class.new(drink_serializer_class) do
      remove_attribute :brand
    end

    person_serializer_class = Class.new(LightweightSerializer::Serializer) do
      serializes type: :person

      attribute(:phone_number) { |object| Phony.format(object.phone_number) }

      group :detailed_name do
        attribute :first_name
        attribute :middle_name
        attribute :last_name
      end

      collection :addresses, serializer: address_serializer_class
      nested :favorite_drink, serializer: drink_serializer_class

      collection :errors, serializer: error_serializer_class do
        [OpenStruct.new(message: 'Test Error #1')]
      end
    end

    foo_serializer_class = Class.new(LightweightSerializer::Serializer) do
      allow_options :user
    end

    bar_serializer_class = Class.new(LightweightSerializer::Serializer) do
      allow_options :user
    end

    foo_bar_serializer_class = Class.new(LightweightSerializer::Serializer) do
      nested :foo, serializer: foo_serializer_class
      nested :bar, serializer: bar_serializer_class
    end

    test_model_class = Struct.new(:foo, :bar)

    test_model_serializer_class = Class.new(LightweightSerializer::Serializer) do
      serializes model: test_model_class
    end

    super_duper_test_serializer_class = Class.new(LightweightSerializer::Serializer) do
      serializes model: 'SuperDuperTestModel'
    end

    inherited_super_duper_test_serializer_class = Class.new(super_duper_test_serializer_class)

    super_duper_test_serializer_without_type_class = Class.new(LightweightSerializer::Serializer) do
      no_automatic_type_field!
      serializes model: 'SuperDuperTestModel'
    end

    stub_const('AddressSerializer', address_serializer_class)
    stub_const('PersonSerializer', person_serializer_class)
    stub_const('ErrorSerializer', error_serializer_class)
    stub_const('FooSerializer', foo_serializer_class)
    stub_const('BarSerializer', bar_serializer_class)
    stub_const('FooBarSerializer', foo_bar_serializer_class)
    stub_const('DrinkSerializer', drink_serializer_class)
    stub_const('HeatedDrinkSerializer', heated_drink_serializer_class)
    stub_const('UnbrandedDrinkSerializer', unbranded_drink_serializer_class)
    stub_const('ErrorSerializerWithPrivateMethod', error_serializer_with_private_method_class)
    stub_const('TestModelSerializer', test_model_serializer_class)
    stub_const('SuperDuperTestSerializer', super_duper_test_serializer_class)
    stub_const('InheritedSuperDuperTestSerializer', inherited_super_duper_test_serializer_class)
    stub_const('SuperDuperTestSerializerWithoutTypeField', super_duper_test_serializer_without_type_class)
    stub_const('SomeTestModel', test_model_class)
  end

  let(:drink_model) { OpenStruct.new(brand: 'Coca Cola', name: 'Coke Zero', serving_size: '500 ml') }
  let(:person_model) { OpenStruct.new(first_name: 'John', middle_name: 'Eric', last_name: 'Doe', phone_number: '16465551234', addresses: [address_2_model, address_1_model], favorite_drink: drink_model, errors: []) }
  let(:address_1_model) { OpenStruct.new(type: :office, street: 'Main Boulevard', number: 1337, city: 'Foozen') }
  let(:address_2_model) { OpenStruct.new(type: :private, street: 'Side Street', number: 42, city: 'Foozen') }
  let(:error_model) { OpenStruct.new(message: 'Something went wrong') }

  let(:person_serializer) { PersonSerializer.new(person_model) }
  let(:address_serializer) { AddressSerializer.new(address_1_model) }
  let(:error_serializer) { ErrorSerializer.new(error_model) }

  let(:expected_person_attributes) do
    [
      :phone_number,
      :detailed_name,
      :addresses,
      :favorite_drink,
      :errors,
      :type
    ]
  end

  let(:detailed_name_attributes) do
    [
      :first_name,
      :middle_name,
      :last_name
    ]
  end

  describe 'attributes' do
    it 'defines the correct attributes on the serializers' do
      expect(PersonSerializer.__lws_defined_attributes.keys).to match_array([:first_name, :middle_name, :last_name, :phone_number])
      expect(AddressSerializer.__lws_defined_attributes.keys).to match_array([:address_type, :street, :number, :city])
      expect(DrinkSerializer.__lws_defined_attributes.keys).to match_array([:brand, :name, :serving_size])
    end

    it 'defines the correct groupings' do
      expect(PersonSerializer.__lws_defined_attributes[:first_name].group).to eq(:detailed_name)
      expect(PersonSerializer.__lws_defined_attributes[:middle_name].group).to eq(:detailed_name)
      expect(PersonSerializer.__lws_defined_attributes[:last_name].group).to eq(:detailed_name)
    end

    it 'defines the correct nested objects on the serializers' do
      expect(PersonSerializer.__lws_defined_nested_serializers.keys).to match_array([:addresses, :errors, :favorite_drink])

      expect(AddressSerializer.__lws_defined_nested_serializers.keys).to be_blank
    end

    describe 'inheritance' do
      it 'also includes attributes defined on the parent class' do
        expect(HeatedDrinkSerializer.__lws_defined_attributes.keys).to eq(DrinkSerializer.__lws_defined_attributes.keys + [:optimal_drinking_temperature])
      end

      it 'allows removing attributes defined on the parent class' do
        expect(UnbrandedDrinkSerializer.__lws_defined_attributes.keys).to match_array([:name, :serving_size])
      end
    end
  end

  context 'allowed options' do
    it 'allows manually adding allowed options' do
      expect(AddressSerializer.__lws_allowed_options).to match_array([:look_up_zip_for_city])
    end

    it 'allows all options that are allowed by serializers used for nested models' do
      expect(PersonSerializer.__lws_allowed_options).to match_array(AddressSerializer.__lws_allowed_options + DrinkSerializer.__lws_allowed_options)
    end

    it 'does not duplicate attributes when they are added twice' do
      expect(FooBarSerializer.__lws_allowed_options).to match_array([:user])
    end
  end

  describe '#as_json' do
    context 'when trying to render a NilClass' do
      it 'returns nil as a result' do
        serializer = PersonSerializer.new(nil)
        expect(serializer.as_json[:data]).to be_nil
      end
    end

    context 'when no_root is set' do
      it 'does not create a root node' do
        expect(error_serializer.as_json).to be_kind_of(Hash)
        expect(error_serializer.as_json).not_to have_key(:data)
        expect(error_serializer.as_json.keys).to match_array(ErrorSerializer.__lws_defined_attributes.keys + [:type])
      end

      context 'when meta data is given' do
        let(:meta) { { page: 1, more: false } }
        let(:serializer) { ErrorSerializer.new(error_model, meta: meta) }

        it 'does not add the meta element' do
          expect(serializer.as_json).not_to have_key(:meta)
        end
      end
    end

    context 'when meta data is given' do
      let(:meta) { { page: 1, more: false } }
      let(:serializer) { PersonSerializer.new(person_model, meta: meta) }

      it 'includes a meta key next to the data element' do
        expect(serializer.as_json).to have_key(:meta)
        expect(serializer.as_json[:meta]).to eq(meta)
      end
    end

    describe 'attributes' do
      it 'returns a hash with all defined attributes' do
        expect(person_serializer.as_json[:data]).to be_kind_of(Hash)
        expect(person_serializer.as_json[:data].keys).to eq(expected_person_attributes)
      end

      it 'correctly groups attributes' do
        expect(person_serializer.as_json[:data][:detailed_name]).to be_kind_of(Hash)
        expect(person_serializer.as_json[:data][:detailed_name].keys).to eq(detailed_name_attributes)
      end

      it 'uses public_send to access attributes if no block is given' do
        expect(person_model).to receive(:first_name).and_call_original

        person_serializer.as_json
      end

      it 'uses the given block' do
        expect(Phony).to receive(:format).with(person_model.phone_number).and_call_original

        person_serializer.as_json
      end

      it 'allows access to private methods defined in the serializer from the block' do
        serializer = ErrorSerializerWithPrivateMethod.new(error_model)

        expect(serializer.as_json[:data][:translated_message]).to eq(error_model.message.reverse)
      end

      context 'conditional attributes' do
        it 'automatically adds the conditional options to the __lws_allowed_options hash' do
          expect(DrinkSerializer.__lws_allowed_options).to match_array([:show_serving_size])
        end

        it 'does not serialize attributes with a condition when the condition is not passed as an option' do
          serializer = DrinkSerializer.new(drink_model, {})
          expect(serializer.as_json[:data]).not_to have_key(:serving_size)
        end

        it 'does not serialize attributes with a condition when the condition is passed as an option but evaluates to false' do
          serializer = DrinkSerializer.new(drink_model, show_serving_size: false)
          expect(serializer.as_json[:data]).not_to have_key(:serving_size)
        end

        it 'serializes attributes with a condition when the condition is passed as an option and evaluates to true' do
          serializer = DrinkSerializer.new(drink_model, show_serving_size: true)
          expect(serializer.as_json[:data]).to have_key(:serving_size)
        end
      end
    end

    describe 'nested objects' do
      it 'uses the given serializer' do
        expect(DrinkSerializer).to receive(:new).with(drink_model, skip_root: true).and_call_original

        person_serializer.as_json
      end

      it 'renders the nested object with the given serializer' do
        serialized_drink = DrinkSerializer.new(drink_model, skip_root: true).as_json

        expect(person_serializer.as_json[:data][:favorite_drink]).to be_kind_of(Hash)
        expect(person_serializer.as_json[:data][:favorite_drink]).to eq(serialized_drink)
      end

      it 'does not render an additional root node in the nested object' do
        expect(person_serializer.as_json[:data][:favorite_drink]).not_to have_key(:data)
      end

      it 'returns nil when the object is not set' do
        person_model.favorite_drink = nil
        expect(person_serializer.as_json[:data][:favorite_drink]).to be_nil
      end

      it 'passes options down to the nested objects' do
        serializer = PersonSerializer.new(person_model, show_serving_size: true, look_up_zip_for_city: true)

        expect(AddressSerializer).to receive(:new).with(Array, skip_root: true, look_up_zip_for_city: true).and_call_original
        expect(DrinkSerializer).to receive(:new).with(drink_model, skip_root: true, show_serving_size: true).and_call_original

        serializer.as_json
      end
    end

    describe 'collections' do
      it 'uses the given serializer' do
        expect(AddressSerializer).to receive(:new).with([address_2_model, address_1_model], skip_root: true).and_call_original

        person_serializer.as_json
      end

      it 'renders the nested collection with the given serializer' do
        expect(person_serializer.as_json[:data][:addresses]).to be_kind_of(Array)
        expect(person_serializer.as_json[:data][:addresses].count).to eq(2)

        expect(person_serializer.as_json[:data][:addresses]).to match_array(
          [
            AddressSerializer.new(address_1_model, skip_root: true).as_json,
            AddressSerializer.new(address_2_model, skip_root: true).as_json
          ]
        )
      end

      it 'preserves the order of the elements' do
        expect(person_serializer.as_json[:data][:addresses].first).to eq(AddressSerializer.new(address_2_model, skip_root: true).as_json)
        expect(person_serializer.as_json[:data][:addresses].second).to eq(AddressSerializer.new(address_1_model, skip_root: true).as_json)
      end

      it 'uses the block instead of accessing the attribute' do
        expect(person_model).not_to receive(:errors)

        expect(person_serializer.as_json[:data][:errors]).to be_kind_of(Array)
        expect(person_serializer.as_json[:data][:errors].count).to eq(1)
      end

      it 'returns an empty array when the collection is empty' do
        person_model.addresses = []

        expect(person_serializer.as_json[:data][:addresses]).to be_kind_of(Array)
        expect(person_serializer.as_json[:data][:addresses]).to be_empty
      end

      it 'returns nil when the collection is nil' do
        person_model.addresses = nil
        expect(person_serializer.as_json[:data][:addresses]).to be_nil
      end
    end

    describe 'when called with an array' do
      let(:people) { [person_model, person_model, person_model] }
      let(:person_serializer) { PersonSerializer.new(people) }

      let(:errors) { [error_model, error_model] }
      let(:error_serializer) { ErrorSerializer.new(errors) }

      context 'and a root element is requested' do
        it 'returns a hash with a data root and an array of elements' do
          expect(person_serializer.as_json).to have_key(:data)
          expect(person_serializer.as_json[:data]).to be_kind_of(Array)
          expect(person_serializer.as_json[:data].count).to eq(people.count)
        end
      end

      context 'and no root element is requested' do
        it 'returns a hash with a data root and an array of elements' do
          expect(error_serializer.as_json).to be_kind_of(Array)
          expect(error_serializer.as_json.count).to eq(errors.count)
        end
      end
    end

    context 'type field generation' do
      it 'does not generate a type field, when no_automatic_type_field! is used' do
        serializer = SuperDuperTestSerializerWithoutTypeField.new(SomeTestModel.new)
        expect(serializer.as_json[:data]).not_to have_key(:type)
      end

      it 'returns the type as given when using `serializes type:`' do
        expect(address_serializer.as_json[:data][:type]).to eq(:address)
      end

      it 'returns an underscored class name when a class is given' do
        serializer = TestModelSerializer.new(OpenStruct.new)
        expect(serializer.as_json[:data][:type]).to eq('some_test_model')
      end

      it 'returns an underscored version of the String when a String is given' do
        serializer = SuperDuperTestSerializer.new(OpenStruct.new)
        expect(serializer.as_json[:data][:type]).to eq('super_duper_test_model')
      end

      it 'keeps the type information through inheritance' do
        serializer = InheritedSuperDuperTestSerializer.new(OpenStruct.new)
        expect(serializer.as_json[:data][:type]).to eq('super_duper_test_model')
      end

      it 'returns the serialized objects class name when nothing is specified' do
        serializer = FooBarSerializer.new(SomeTestModel.new)
        expect(serializer.as_json[:data][:type]).to eq('some_test_model')
      end
    end
  end

  describe '#to_json' do
    it 'returns a JSON string' do
      expect(person_serializer.to_json).to be_kind_of(String)
      expect(person_serializer.to_json).to eq(person_serializer.as_json.to_json)
    end
  end

  describe 'restricted attribute names' do
    it 'allows `type` as an attribute name when `no_automatic_type_field!` macro is used' do
      expect do
        Class.new(LightweightSerializer::Serializer) do
          no_automatic_type_field!
          attribute :type
        end
      end.not_to raise_error
    end

    it 'does not allow `type` as a serialized attribute name' do
      expect do
        Class.new(LightweightSerializer::Serializer) do
          attribute :type
        end
      end.to raise_error(ArgumentError, 'cannot use "type" as an attribute name')
    end

    it 'does not allow `type` as a group name' do
      expect do
        Class.new(LightweightSerializer::Serializer) do
          group :type do
            attribute :foo
          end
        end
      end.to raise_error(ArgumentError, 'cannot use "type" as a group name')
    end

    it 'does not allow `type` as a nested name' do
      expect do
        Class.new(LightweightSerializer::Serializer) do
          nested :type, serializer: AddressSerializer
        end
      end.to raise_error(ArgumentError, 'cannot use "type" as a nested attribute name')
    end

    it 'does not allow `type` as a collection name' do
      expect do
        Class.new(LightweightSerializer::Serializer) do
          collection :type, serializer: AddressSerializer
        end
      end.to raise_error(ArgumentError, 'cannot use "type" as a nested collection name')
    end
  end
end
