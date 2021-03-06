RSpec.describe ErrorItemsHelper do
  describe "#error_items" do
    it "extracts only the errors relevant to the field" do
      errors = [
        {
          field: "name",
          text: "Enter your name.",
        },
        {
          field: "email",
          text: "This does not look like a valid email address.",
        },
      ]
      expect(error_items("name", errors)).to eq("Enter your name.")
      expect(error_items("email", errors)).to eq("This does not look like a valid email address.")
    end

    it "merges multiple errors for the desired field" do
      errors = [
        {
          field: "email",
          text: "This does not look like a valid email address.",
        },
        {
          field: "email",
          text: "Enter an email address in this format: name@example.com.",
        },
      ]
      expect(error_items("email", errors)).to eq("This does not look like a valid email address.<br>Enter an email address in this format: name@example.com.")
    end

    it "adds 'Error' to the page title when there has been an error" do
      errors = [
        {
          field: "email",
          text: "This does not look like a valid email address.",
        },
      ]
      error_items("email", errors)
      expect(content_for(:title_prefix)).to eq("Error")
    end

    it "Does not change the page title if there has not been an error" do
      errors = nil
      error_items("email", errors)
      expect(content_for?(:title_prefix)).to eq(false)
    end
  end
end
