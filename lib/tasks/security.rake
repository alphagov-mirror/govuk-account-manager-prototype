namespace :security do
  desc "Import the NCSC's password denylist.  This clears the current denylist."
  task import_ncsc_denylist: :environment do
    count = BannedPassword.import_from_ncsc
    puts "imported #{count} passwords"
  end

  desc "Check usage of passwords on NCSC's password denylist."
  task check_ncsc_denylist_usage: :environment do
    User.where(ncsc_password_match: nil).each do |user|
      NcscUserPasswordCheckJob.perform_later(user.id)
    end
  end
end
