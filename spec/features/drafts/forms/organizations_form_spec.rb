# MMT-381

require 'rails_helper'

describe 'Organizations form', js: true do
  before do
    login
    draft = create(:draft, user: User.where(urs_uid: 'testuser').first)
    visit draft_path(draft)
  end

  context 'when submitting the form' do
    before do
      within '.metadata' do
        click_on 'Organizations', match: :first
      end

      # Organization
      within '#organizations' do
        add_responsibilities('organizations')
      end

      within '.nav-top' do
        click_on 'Save'
      end
      expect(page).to have_content('Organizations')
      # output_schema_validation Draft.first.draft
      open_accordions
    end

    it 'displays a confirmation message' do
      expect(page).to have_content('Draft was successfully updated')
    end

    it 'populates the form with the values' do
      #### Organizations
      within '.multiple.organizations > .multiple-item-0' do
        expect(page).to have_field('Role', with: 'RESOURCEPROVIDER')
        expect(page).to have_field('Short Name', with: 'AARHUS-HYDRO')
        expect(page).to have_field('Long Name', with: 'Hydrogeophysics Group, Aarhus University ', readonly: true)
        expect(page).to have_field('Service Hours', with: '9-5, M-F')
        expect(page).to have_field('Contact Instructions', with: 'Email only')
        within '.multiple.contacts' do
          within '.multiple-item-0' do
            expect(page).to have_field('Type', with: 'Email')
            expect(page).to have_field('Value', with: 'example@example.com')
          end
          within '.multiple-item-1' do
            expect(page).to have_field('Type', with: 'Email')
            expect(page).to have_field('Value', with: 'example2@example.com')
          end
        end
        within '.multiple.addresses > .multiple-item-0' do
          expect(page).to have_field('Street Address - Line 1', with: '300 E Street Southwest')
          expect(page).to have_field('Street Address - Line 2', with: 'Room 203')
          expect(page).to have_field('Street Address - Line 3', with: 'Address line 3')
          expect(page).to have_field('City', with: 'Washington')
          expect(page).to have_field('State / Province', with: 'District of Columbia')
          expect(page).to have_field('Postal Code', with: '20546')
          expect(page).to have_field('Country', with: 'United States')
        end
        within '.multiple.addresses > .multiple-item-1' do
          expect(page).to have_field('Street Address - Line 1', with: '8800 Greenbelt Road')
          expect(page).to have_field('City', with: 'Greenbelt')
          expect(page).to have_field('State / Province', with: 'Maryland')
          expect(page).to have_field('Postal Code', with: '20771')
          expect(page).to have_field('Country', with: 'United States')
        end
        within '.multiple.related-urls > .multiple-item-0' do
          expect(page).to have_selector('input.url[value="http://example.com"]')
          expect(page).to have_selector('input.url[value="http://another-example.com"]')
          expect(page).to have_field('Description', with: 'Example Description')
          expect(page).to have_field('Title', with: 'Example Title')
        end
        within '.multiple.related-urls > .multiple-item-1' do
          expect(page).to have_selector('input.url[value="http://example.com/1"]')
        end
      end
      within '.multiple.organizations > .multiple-item-1' do
        expect(page).to have_field('Role', with: 'OWNER')
        expect(page).to have_field('Short Name', with: 'ESA/ED')
        expect(page).to have_field('Long Name', with: 'Educational Office, Ecological Society of America', readonly: true)
        expect(page).to have_field('Service Hours', with: '10-2, M-W')
        expect(page).to have_field('Contact Instructions', with: 'Email only')
        within '.multiple.contacts' do
          within '.multiple-item-0' do
            expect(page).to have_field('Type', with: 'Email')
            expect(page).to have_field('Value', with: 'example@example.com')
          end
          within '.multiple-item-1' do
            expect(page).to have_field('Type', with: 'Email')
            expect(page).to have_field('Value', with: 'example2@example.com')
          end
        end
        within '.multiple.addresses > .multiple-item-0' do
          expect(page).to have_field('Street Address - Line 1', with: '300 E Street Southwest')
          expect(page).to have_field('Street Address - Line 2', with: 'Room 203')
          expect(page).to have_field('Street Address - Line 3', with: 'Address line 3')
          expect(page).to have_field('City', with: 'Washington')
          expect(page).to have_field('State / Province', with: 'District of Columbia')
          expect(page).to have_field('Postal Code', with: '20546')
          expect(page).to have_field('Country', with: 'United States')
        end
        within '.multiple.addresses > .multiple-item-1' do
          expect(page).to have_field('Street Address - Line 1', with: '8800 Greenbelt Road')
          expect(page).to have_field('City', with: 'Greenbelt')
          expect(page).to have_field('State / Province', with: 'Maryland')
          expect(page).to have_field('Postal Code', with: '20771')
          expect(page).to have_field('Country', with: 'United States')
        end
        within '.multiple.related-urls > .multiple-item-0' do
          expect(page).to have_selector('input.url[value="http://www.esa.org/education/"]')
          expect(page).to have_selector('input.url[value="http://another-example.com"]')
          expect(page).to have_field('Description', with: 'Example Description')
          expect(page).to have_field('Title', with: 'Example Title')
        end
        within '.multiple.related-urls > .multiple-item-1' do
          expect(page).to have_selector('input.url[value="http://example.com/1"]')
        end
      end
    end
  end
end
