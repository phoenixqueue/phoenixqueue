RSpec.describe Phoenixqueue::Job do
  it "validates required fields" do
    job = described_class.new
    expect(job).not_to be_valid

    expect(job.errors.attribute_names).to include(:job_class, :payload, :status, :run_at)

    job.queue = nil
    job.validate
    expect(job.errors.attribute_names).to include(:queue)
  end
end

