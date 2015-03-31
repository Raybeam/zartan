require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

RSpec.describe ApiKeysController, type: :controller do

  # This should return the minimal set of attributes required to create a valid
  # ApiKey. As you add validations to ApiKey, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {Hash.new}

  let(:invalid_attributes) {Hash.new}

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # ApiKeysController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET #index" do
    it "assigns all api_keys as @api_keys" do
      api_key = create(:api_key)
      get :index
      expect(assigns(:api_keys)).to eq([api_key])
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new ApiKey" do
        expect {
          post :create, {:api_key => valid_attributes}, valid_session
        }.to change(ApiKey, :count).by(1)
      end

      it "assigns a newly created api_key as @api_key" do
        post :create, {:api_key => valid_attributes}, valid_session
        expect(assigns(:api_key)).to be_a(ApiKey)
        expect(assigns(:api_key)).to be_persisted
      end

      it "redirects to the created api_key" do
        post :create, {:api_key => valid_attributes}, valid_session
        expect(response).to redirect_to(ApiKey.last)
      end
    end

    context "with invalid params" do
      it "assigns a newly created but unsaved api_key as @api_key" do
        post :create, {:api_key => invalid_attributes}, valid_session
        expect(assigns(:api_key)).to be_a_new(ApiKey)
      end

      it "re-renders the 'new' template" do
        post :create, {:api_key => invalid_attributes}, valid_session
        expect(response).to render_template("new")
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested api_key" do
        api_key = ApiKey.create! valid_attributes
        put :update, {:id => api_key.to_param, :api_key => new_attributes}, valid_session
        api_key.reload
        skip("Add assertions for updated state")
      end

      it "assigns the requested api_key as @api_key" do
        api_key = ApiKey.create! valid_attributes
        put :update, {:id => api_key.to_param, :api_key => valid_attributes}, valid_session
        expect(assigns(:api_key)).to eq(api_key)
      end

      it "redirects to the api_key" do
        api_key = ApiKey.create! valid_attributes
        put :update, {:id => api_key.to_param, :api_key => valid_attributes}, valid_session
        expect(response).to redirect_to(api_key)
      end
    end

    context "with invalid params" do
      it "assigns the api_key as @api_key" do
        api_key = ApiKey.create! valid_attributes
        put :update, {:id => api_key.to_param, :api_key => invalid_attributes}, valid_session
        expect(assigns(:api_key)).to eq(api_key)
      end

      it "re-renders the 'edit' template" do
        api_key = ApiKey.create! valid_attributes
        put :update, {:id => api_key.to_param, :api_key => invalid_attributes}, valid_session
        expect(response).to render_template("edit")
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested api_key" do
      api_key = ApiKey.create! valid_attributes
      expect {
        delete :destroy, {:id => api_key.to_param}, valid_session
      }.to change(ApiKey, :count).by(-1)
    end

    it "redirects to the api_keys list" do
      api_key = ApiKey.create! valid_attributes
      delete :destroy, {:id => api_key.to_param}, valid_session
      expect(response).to redirect_to(api_keys_url)
    end
  end

end
