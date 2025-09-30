# frozen_string_literal: true

RSpec.describe Grape::Entity::Preloader do
  let(:exposures) { double('exposures') }
  let(:objects) { [{ id: 1 }, { id: 2 }] }
  let(:options) { Grape::Entity::Options.new(serializable: true, enable_preloader: true) }

  describe '#call' do
    let(:exposures) { [] }  # Empty array to respond to each
    let(:preloader) { described_class.new(exposures, objects, options) }
    let(:mock_preloader) { double('ActiveRecord::Associations::Preloader') }

    before do
      allow(ActiveRecord::Associations::Preloader).to receive(:new).and_return(mock_preloader)
      allow(mock_preloader).to receive(:call)
    end

    it 'calls ActiveRecord::Associations::Preloader' do
      expect(ActiveRecord::Associations::Preloader).to receive(:new).with(records: objects, associations: {})
      expect(mock_preloader).to receive(:call)

      preloader.call
    end

    context 'with exposures that have preload_association' do
      let(:exposure1) { double('exposure1') }
      let(:exposure2) { double('exposure2') }
      let(:exposures) { [exposure1, exposure2] }

      before do
        allow(exposure1).to receive(:should_return_key?).with(options).and_return(true)
        allow(exposure2).to receive(:should_return_key?).with(options).and_return(true)
        allow(exposure1).to receive(:preload_association).and_return(:books)
        allow(exposure2).to receive(:preload_association).and_return(nil)
        allow(exposure1).to receive(:preload_callback).and_return(nil)
        allow(exposure2).to receive(:preload_callback).and_return(nil)
        allow(exposure1).to receive(:instance_variable_get).with(:@key).and_return(:books)
        allow(exposure2).to receive(:instance_variable_get).with(:@key).and_return(:name)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(false)
        allow(exposure2).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(false)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(false)
        allow(exposure2).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(false)
      end

      it 'extracts preload associations' do
        expect(ActiveRecord::Associations::Preloader).to receive(:new).with(records: objects, associations: { books: {} })
        expect(mock_preloader).to receive(:call)

        preloader.call
      end
    end

    context 'with exposures that have preload_callback' do
      let(:exposure1) { double('exposure1') }
      let(:exposures) { [exposure1] }
      let(:callback_proc) { proc { |objects| objects } }
      let(:association_objects) { [{ id: 1 }, { id: 2 }] }

      before do
        allow(exposure1).to receive(:should_return_key?).with(options).and_return(true)
        allow(exposure1).to receive(:preload_association).and_return(nil)
        allow(exposure1).to receive(:preload_callback).and_return(callback_proc)
        allow(exposure1).to receive(:instance_variable_get).with(:@key).and_return(:related_data)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(false)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(false)
        allow(callback_proc).to receive(:call).and_return(association_objects)
      end

      it 'handles preload callbacks' do
        expect(ActiveRecord::Associations::Preloader).to receive(:new).with(records: objects, associations: {})
        expect(mock_preloader).to receive(:call)
        expect(callback_proc).to receive(:call).with(objects).and_return(association_objects)

        preloader.call
      end
    end

    context 'with nested exposures' do
      let(:nested_exposure) { double('nested_exposure', should_return_key?: true, preload_association: :books, preload_callback: nil, instance_variable_get: :books) }
      let(:exposure1) { double('exposure1', should_return_key?: true, preload_association: :author, preload_callback: nil, nested_exposures: [nested_exposure], instance_variable_get: :author) }

      before do
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(true)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(false)
        allow(options).to receive(:for_nesting).with(:author).and_return(options)
        preloader.instance_variable_set(:@exposures, [exposure1])
      end

      it 'handles nested exposures' do
        expect(ActiveRecord::Associations::Preloader).to receive(:new).with(records: objects, associations: { author: {}, books: {} })
        expect(mock_preloader).to receive(:call)

        preloader.call
      end
    end

    context 'with RepresentExposure' do
      let(:using_class) { double('using_class', root_exposures: []) }
      let(:exposure1) { double('exposure1', should_return_key?: true, preload_association: :related_items, preload_callback: nil, using_class: using_class, instance_variable_get: :related_items) }

      before do
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(false)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(true)
        allow(options).to receive(:for_nesting).with(:related_items).and_return(options)
        preloader.instance_variable_set(:@exposures, [exposure1])
      end

      it 'handles RepresentExposure' do
        expect(ActiveRecord::Associations::Preloader).to receive(:new).with(records: objects, associations: { related_items: {} })
        expect(mock_preloader).to receive(:call)

        preloader.call
      end
    end
  end

  describe '#extract_preload_options' do
    let(:preloader) { described_class.new(exposures, objects, options) }
    let(:associations) { {} }
    let(:exposures_with_callback) { {} }

    # Test the method indirectly through the call method or use send to access private method
    let(:test_exposures) { exposures }
    let(:test_options) { options }
    let(:test_associations) { associations }
    let(:test_exposures_with_callback) { exposures_with_callback }

    context 'with simple exposure' do
      let(:exposure1) { double('exposure1') }
      let(:exposures) { [exposure1] }

      before do
        allow(exposure1).to receive(:should_return_key?).with(options).and_return(true)
        allow(exposure1).to receive(:preload_association).and_return(:books)
        allow(exposure1).to receive(:preload_callback).and_return(nil)
        allow(exposure1).to receive(:instance_variable_get).with(:@key).and_return(:books)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(false)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(false)
      end

      it 'extracts preload association' do
        preloader.send(:extract_preload_options, test_exposures, test_options, test_associations, test_exposures_with_callback)
        expect(test_associations).to eq({ books: {} })
      end
    end

    context 'with exposure that should not return key' do
      let(:exposure1) { double('exposure1') }
      let(:exposures) { [exposure1] }

      before do
        allow(exposure1).to receive(:should_return_key?).with(options).and_return(false)
      end

      it 'skips the exposure' do
        preloader.send(:extract_preload_options, test_exposures, test_options, test_associations, test_exposures_with_callback)
        expect(test_associations).to eq({})
      end
    end

    context 'with dynamic key exposure' do
      let(:exposure1) { double('exposure1') }
      let(:exposures) { [exposure1] }
      let(:dynamic_key) { proc { :dynamic_key } }

      before do
        allow(exposure1).to receive(:should_return_key?).with(options).and_return(true)
        allow(exposure1).to receive(:preload_association).and_return(:books)
        allow(exposure1).to receive(:preload_callback).and_return(nil)
        allow(exposure1).to receive(:instance_variable_get).with(:@key).and_return(dynamic_key)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(false)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(false)
      end

      it 'skips dynamic key exposures but still processes preload_association' do
        preloader.send(:extract_preload_options, test_exposures, test_options, test_associations, test_exposures_with_callback)
        # The dynamic key check skips further processing, but preload_association is already set
        expect(test_associations).to eq({ books: {} })
      end
    end

    context 'with callback exposure' do
      let(:exposure1) { double('exposure1') }
      let(:exposures) { [exposure1] }
      let(:callback_proc) { proc { |objects| objects } }

      before do
        allow(exposure1).to receive(:should_return_key?).with(options).and_return(true)
        allow(exposure1).to receive(:preload_association).and_return(nil)
        allow(exposure1).to receive(:preload_callback).and_return(callback_proc)
        allow(exposure1).to receive(:instance_variable_get).with(:@key).and_return(:callback_data)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::NestingExposure).and_return(false)
        allow(exposure1).to receive(:is_a?).with(Grape::Entity::Exposure::RepresentExposure).and_return(false)
      end

      it 'adds exposure to callbacks hash' do
        preloader.send(:extract_preload_options, test_exposures, test_options, test_associations, test_exposures_with_callback)
        expect(test_exposures_with_callback).to eq({ '' => [exposure1, options] })
      end
    end
  end
end
