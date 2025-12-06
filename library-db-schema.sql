-- ============================================================================
-- LIBRARY `subject` INDEX SYSTEM - COMPLETE DATABASE SCHEMA
-- Database: MySQL 8.0+
-- Purpose: Multi-branch library management with `subject`-based indexing
-- ============================================================================

-- Drop existing database and create fresh
DROP DATABASE IF EXISTS library_index_system;
CREATE DATABASE library_index_system;

USE library_index_system;

-- ============================================================================
-- ENTITY: publisher
-- Purpose: Store information about book publishers
-- ============================================================================
CREATE TABLE publisher (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(200) NOT NULL UNIQUE,
    country VARCHAR(100),
    established_year DECIMAL(4,0) UNSIGNED,  -- I'm using an unsigned decimal because MySQL `year` data type does not suppor years below 1901
    website VARCHAR(255),                    -- TODO: Create validation regex for website URLs
    contact_email VARCHAR(100),
    contact_phone VARCHAR(15),               -- Allows us to accomodate the longest mobile numbers in the world 15-digits 
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- CONSTRAINTS
    -- CONSTRAINT chk_publisher_year CHECK (established_year >= 1440 AND established_year <= YEAR(CURRENT_TIMESTAMP)), -- I am unable to use this, I can provide more context in the document we are submitting
    CONSTRAINT year_above_867 CHECK (established_year >= 1450 ),
    CONSTRAINT chk_email_format CHECK (contact_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') -- This validates the email provided
) ENGINE=InnoDB;

-- Indexes for search optimization 
CREATE INDEX idx_publisher_name ON publisher(`name`);
CREATE INDEX idx_publisher_country ON publisher(country);

-- ============================================================================
-- ENTITY: `subject`
-- Purpose: Categorize books into `subject` areas
-- ============================================================================
CREATE TABLE `subject` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    subject_code VARCHAR(10) UNIQUE NOT NULL,
    `name` VARCHAR(100) UNIQUE NOT NULL,
    parent_subject_id INT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        
    -- FOREIGN KEYS (self-referencing for hierarchical subjects)
    CONSTRAINT fk_parent_subject FOREIGN KEY (parent_subject_id) 
        REFERENCES `subject`(id) 
        ON DELETE SET NULL 
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_subject_name ON `subject`(`name`);
CREATE INDEX idx_subject_code ON `subject`(subject_code);
CREATE INDEX idx_parent_subject ON `subject`(parent_subject_id);

-- ============================================================================
-- ENTITY: branch
-- Purpose: Represent physical library branches/locations
-- ============================================================================
CREATE TABLE branch (
    id INT AUTO_INCREMENT PRIMARY KEY,
    branch_code VARCHAR(10) UNIQUE NOT NULL,
    `name` VARCHAR(150) UNIQUE NOT NULL,
    address_line1 VARCHAR(200) NOT NULL,
    address_line2 VARCHAR(200),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL DEFAULT 'USA',
    phone VARCHAR(15),                              -- Allows us to accomodate the longest mobile numbers in the world 15-digits 
    email VARCHAR(100),
    manager_name VARCHAR(150),
    opening_hours TEXT,
    seating_capacity INT,
    is_active BOOLEAN DEFAULT TRUE,
    established_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        
    -- CONSTRAINTS
    CONSTRAINT chk_seating_capacity CHECK (seating_capacity >= 0),
    CONSTRAINT chk_email_branch CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_branch_code ON branch(branch_code);
CREATE INDEX idx_branch_city ON branch(city);
CREATE INDEX idx_branch_active ON branch(is_active);

-- ============================================================================
-- ENTITY: author
-- Purpose: Store author information
-- ============================================================================
CREATE TABLE author (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    gender ENUM('Male', 'Female', 'Not Provided', 'Other') DEFAULT 'Not Provided',
    birth_date DATE,
    death_date DATE,
    nationality VARCHAR(100),
    biography TEXT,
    website VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- CONSTRAINTS
    CONSTRAINT chk_death_after_birth CHECK (death_date IS NULL OR death_date >= birth_date)
    -- CONSTRAINT chk_birth_date CHECK (birth_date IS NULL OR birth_date <= CURRENT_TIMESTAMP) -- TODO: MySQL doesnt support this
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_author_last_name ON author(last_name, first_name);
CREATE INDEX idx_author_full_name ON author(first_name, last_name);

-- ============================================================================
-- ENTITY: book
-- Purpose: Core entity representing book publications
-- ============================================================================
CREATE TABLE book (
    id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(17) UNIQUE NOT NULL,
    title VARCHAR(500) NOT NULL,
    subtitle VARCHAR(500),
    edition VARCHAR(50),
    publication_year DECIMAL(4,0) UNSIGNED,  -- I'm using an unsigned decimal because MySQL `year` data type does not suppor years below 1901
    language VARCHAR(50) DEFAULT 'English',
    pages INT UNSIGNED,
    format ENUM('Hardcover', 'Paperback', 'eBook', 'Audiobook', 'Magazine', 'Journal') DEFAULT 'Paperback',
    description TEXT,
    publisher_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        
    -- FOREIGN KEYS
    CONSTRAINT fk_book_publisher FOREIGN KEY (publisher_id) 
        REFERENCES publisher(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- CONSTRAINTS
    CONSTRAINT chk_isbn_format CHECK (
        isbn REGEXP '^(97[89]-)?[0-9]{1,5}-[0-9]{1,7}-[0-9]{1,7}-[0-9X]$'
        OR isbn REGEXP '^[0-9]{9}[0-9X]$'
        OR isbn REGEXP '^[0-9]{13}$'
    ),
--     CONSTRAINT chk_publication_year CHECK (
--         publication_year >= 1440 AND publication_year <= YEAR(CURDATE()) + 1 -- MySQL doesnt support this.
--     ),
    CONSTRAINT chk_publication_year CHECK (publication_year >= 1450), -- Johannes Gutenberg's invention of the movable-type printing press
    CONSTRAINT chk_pages CHECK (pages > 0) -- TODO: Check if this is still required as the column is already defined as 'UNSIGNED' integer
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_book_isbn ON book(isbn);
CREATE INDEX idx_book_title ON book(title);
CREATE INDEX idx_book_publisher ON book(id);
CREATE INDEX idx_book_publication_year ON book(publication_year);
CREATE FULLTEXT INDEX idx_book_fulltext ON book(`title`, `subtitle`, `description`);

-- ============================================================================
-- JUNCTION TABLE: book_author
-- Purpose: Implement many-to-many relationship between books and authors
-- ============================================================================
CREATE TABLE book_author (
    book_id INT NOT NULL,
    author_id INT NOT NULL,
    author_sequence TINYINT UNSIGNED NOT NULL DEFAULT 1,
    contribution_type ENUM('Primary author', 'Co-author', 'Editor', 'Translator', 'Illustrator') DEFAULT 'Primary author',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- COMPOSITE PRIMARY KEY
    PRIMARY KEY (book_id, author_id),
    
    -- FOREIGN KEYS
    CONSTRAINT fk_ba_book FOREIGN KEY (book_id) 
        REFERENCES book(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT fk_ba_author FOREIGN KEY (author_id) 
        REFERENCES author(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    
    -- CONSTRAINTS
    CONSTRAINT chk_author_sequence CHECK (author_sequence > 0)
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_ba_author ON book_author(author_id);
CREATE INDEX idx_ba_contribution ON book_author(contribution_type);

-- ============================================================================
-- JUNCTION TABLE: book_subject
-- Purpose: Implement many-to-many relationship between books and subjects
-- ============================================================================
CREATE TABLE book_subject (
    book_id INT NOT NULL,
    subject_id INT NOT NULL,
    is_primary_subject BOOLEAN DEFAULT FALSE,
    assigned_date DATE,
    assigned_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- COMPOSITE PRIMARY KEY
    PRIMARY KEY (book_id, subject_id),
    
    -- FOREIGN KEYS
    CONSTRAINT fk_bs_book FOREIGN KEY (book_id)
        REFERENCES book(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_bs_subject FOREIGN KEY (subject_id)
        REFERENCES `subject`(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_bs_subject ON book_subject(subject_id);
CREATE INDEX idx_bs_primary ON book_subject(is_primary_subject);

-- ============================================================================
-- ENTITY: book_copy
-- Purpose: Track individual physical copies of books
-- ============================================================================
CREATE TABLE book_copy (
    id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    branch_id INT NOT NULL,
    barcode VARCHAR(50) UNIQUE NOT NULL,
    acquisition_date DATE NOT NULL,
    acquisition_cost DECIMAL(10,2),
    condition_status ENUM('Excellent', 'Good', 'Fair', 'Poor', 'Damaged') DEFAULT 'Excellent',
    availability_status ENUM('Available', 'Checked Out', 'Reserved', 'In Repair', 'Lost', 'Withdrawn') DEFAULT 'Available',
    shelf_location VARCHAR(50),
    last_inventory_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- FOREIGN KEYS
    CONSTRAINT fk_copy_book FOREIGN KEY (book_id) 
        REFERENCES book(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_copy_branch FOREIGN KEY (branch_id) 
        REFERENCES branch(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- CONSTRAINTS
    CONSTRAINT chk_barcode_format CHECK (barcode REGEXP '^[0-9A-Z]{8,20}$'),
    CONSTRAINT chk_acquisition_cost CHECK (acquisition_cost >= 0) -- a book cannot be procured less than 0
    -- CONSTRAINT chk_acquisition_date CHECK (acquisition_date <= CURDATE()) -- MySQL doesnt allow us do this
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_copy_book ON book_copy(book_id);
CREATE INDEX idx_copy_branch ON book_copy(branch_id);
CREATE INDEX idx_copy_barcode ON book_copy(barcode);
CREATE INDEX idx_copy_availability ON book_copy(availability_status);
CREATE INDEX idx_copy_book_branch ON book_copy(book_id, branch_id);

-- ============================================================================
-- ENTITY: member
-- Purpose: Store library member/user information
-- ============================================================================
CREATE TABLE `member` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    membership_number VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender ENUM('Male', 'Female', 'Not Provided', 'Other') DEFAULT 'Not Provided',
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15),                  -- Allows us to accomodate the longest mobile numbers in the world 15-digits 
    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100) DEFAULT 'Lagos State',
    country VARCHAR(100) DEFAULT 'Nigeria',
    home_branch_id INT,
    membership_type ENUM('Standard', 'Student', 'Senior', 'Premium', 'Staff', 'Librarian') DEFAULT 'Standard', -- A 'Librarian' is also a 'Staff' but I'm leaving this here all the same
    membership_start_date DATE NOT NULL,
    membership_expiry_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- FOREIGN KEYS
    CONSTRAINT fk_member_branch FOREIGN KEY (home_branch_id) 
        REFERENCES branch(id) 
        ON DELETE SET NULL 
        ON UPDATE CASCADE,
    
    -- CONSTRAINTS
    CONSTRAINT chk_member_email CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_membership_dates CHECK (membership_expiry_date > membership_start_date)
    -- CONSTRAINT chk_member_dob CHECK (date_of_birth IS NULL OR date_of_birth <= CURDATE()) -- MySQL doesnt support this
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_member_number ON member(membership_number);
CREATE INDEX idx_member_email ON member(email);
CREATE INDEX idx_member_name ON member(last_name, first_name);
CREATE INDEX idx_member_branch ON member(home_branch_id);

-- ============================================================================
-- ENTITY: loan
-- Purpose: Track book borrowing transactions
-- ============================================================================
CREATE TABLE loan (
    id INT AUTO_INCREMENT PRIMARY KEY,
    copy_id INT NOT NULL,
    member_id INT NOT NULL,
    branch_id INT NOT NULL, -- TODO: Determine if this this needed or we can track the branch using the 'copy_id'!!!
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    renewal_count TINYINT DEFAULT 0,
    `status` ENUM('Active', 'Returned', 'Overdue', 'Lost') DEFAULT 'Active',
    fine_amount DECIMAL(10,2) DEFAULT 0.00,
    fine_paid BOOLEAN DEFAULT FALSE,
    staff_id VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- FOREIGN KEYS
    CONSTRAINT fk_loan_copy FOREIGN KEY (copy_id) 
        REFERENCES book_copy(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_loan_member FOREIGN KEY (member_id) 
        REFERENCES member(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_loan_branch FOREIGN KEY (branch_id) 
        REFERENCES branch(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- CONSTRAINTS
    CONSTRAINT chk_due_date CHECK (due_date > loan_date),
    CONSTRAINT chk_return_date CHECK (return_date IS NULL OR return_date >= loan_date),
    CONSTRAINT chk_renewal_count CHECK (renewal_count >= 0 AND renewal_count <= 5),
    CONSTRAINT chk_fine_amount CHECK (fine_amount >= 0)
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_loan_copy ON loan(copy_id);
CREATE INDEX idx_loan_member ON loan(member_id);
CREATE INDEX idx_loan_branch ON loan(branch_id);
CREATE INDEX idx_loan_dates ON loan(loan_date, due_date);
CREATE INDEX idx_loan_status ON loan(`status`);
CREATE INDEX idx_loan_overdue ON loan(due_date, `status`);


-- ============================================================================
-- PAYMENT_TYPE: Defines different types of payments in the system
-- ============================================================================
CREATE TABLE payment_type (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    description TEXT,
    default_amount DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_default_amount CHECK (default_amount >= 0)
) ENGINE=InnoDB;

CREATE INDEX idx_payment_type_code ON payment_type(type_code);

-- ============================================================================
-- MEMBERSHIP_FEE_STRUCTURE: Defines fee structure for different membership types
-- ============================================================================
CREATE TABLE membership_fee_structure (
    id INT AUTO_INCREMENT PRIMARY KEY,
    membership_type ENUM('Standard', 'Student', 'Senior', 'Premium', 'Staff', 'Librarian') NOT NULL UNIQUE,
    annual_fee DECIMAL(10,2) NOT NULL,
    monthly_fee DECIMAL(10,2),
    registration_fee DECIMAL(10,2) DEFAULT 0.00,
    renewal_fee DECIMAL(10,2),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL,
    effective_to DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_annual_fee CHECK (annual_fee >= 0),
    CONSTRAINT chk_monthly_fee CHECK (monthly_fee IS NULL OR monthly_fee >= 0),
    CONSTRAINT chk_registration_fee CHECK (registration_fee >= 0),
    CONSTRAINT chk_renewal_fee CHECK (renewal_fee IS NULL OR renewal_fee >= 0),
    CONSTRAINT chk_effective_dates CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE=InnoDB;

CREATE INDEX idx_fee_structure_type ON membership_fee_structure(membership_type);
CREATE INDEX idx_fee_structure_dates ON membership_fee_structure(effective_from, effective_to);

-- ============================================================================
-- FINE_POLICY: Defines policies for calculating fines on overdue items
-- ============================================================================
CREATE TABLE fine_policy (
    id INT AUTO_INCREMENT PRIMARY KEY,
    policy_name VARCHAR(100) NOT NULL,
    membership_type ENUM('Standard', 'Student', 'Senior', 'Premium', 'Staff', 'Librarian'),
    book_format ENUM('Hardcover', 'Paperback', 'eBook', 'Audiobook', 'Magazine', 'Journal'),
    daily_fine_rate DECIMAL(10,2) NOT NULL,
    grace_period_days TINYINT DEFAULT 0,
    maximum_fine DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL,
    effective_to DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_daily_fine_rate CHECK (daily_fine_rate >= 0),
    CONSTRAINT chk_grace_period CHECK (grace_period_days >= 0),
    CONSTRAINT chk_maximum_fine CHECK (maximum_fine IS NULL OR maximum_fine >= 0),
    CONSTRAINT chk_fine_effective_dates CHECK (effective_to IS NULL OR effective_to > effective_from)
) ENGINE=InnoDB;

CREATE INDEX idx_fine_policy_membership ON fine_policy(membership_type);
CREATE INDEX idx_fine_policy_format ON fine_policy(book_format);
CREATE INDEX idx_fine_policy_dates ON fine_policy(effective_from, effective_to);

-- ============================================================================
-- PAYMENT: Core payment table tracking all financial transactions
-- ============================================================================
CREATE TABLE payment (
    id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(50) UNIQUE NOT NULL,
    member_id INT NOT NULL,
    payment_type_id INT NOT NULL,
    loan_id INT, -- NULL for membership payments, populated for fine payments
    amount DECIMAL(10,2) NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_method ENUM('Cash', 'Credit Card', 'Debit Card', 'Mobile Money', 'Bank Transfer', 'Cheque', 'Online Payment') NOT NULL,
    payment_status ENUM('Pending', 'Completed', 'Failed', 'Refunded', 'Cancelled') DEFAULT 'Pending',
    reference_number VARCHAR(100), -- External payment reference (e.g., bank transaction ID)
    processed_by VARCHAR(100), -- Staff member who processed the payment
    branch_id INT, -- Branch where payment was made
    notes TEXT,
    refund_date TIMESTAMP,
    refund_amount DECIMAL(10,2),
    refund_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_payment_member FOREIGN KEY (member_id)
        REFERENCES member(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_payment_type FOREIGN KEY (payment_type_id)
        REFERENCES payment_type(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_payment_loan FOREIGN KEY (loan_id)
        REFERENCES loan(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_payment_branch FOREIGN KEY (branch_id)
        REFERENCES branch(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_payment_amount CHECK (amount >= 0),
    CONSTRAINT chk_refund_amount CHECK (refund_amount IS NULL OR (refund_amount >= 0 AND refund_amount <= amount))
) ENGINE=InnoDB;

CREATE INDEX idx_payment_transaction ON payment(transaction_id);
CREATE INDEX idx_payment_member ON payment(member_id);
CREATE INDEX idx_payment_type ON payment(payment_type_id);
CREATE INDEX idx_payment_loan ON payment(loan_id);
CREATE INDEX idx_payment_date ON payment(payment_date);
CREATE INDEX idx_payment_status ON payment(payment_status);
CREATE INDEX idx_payment_method ON payment(payment_method);
CREATE INDEX idx_payment_branch ON payment(branch_id);

-- ============================================================================
-- MEMBERSHIP_PAYMENT: Links payments specifically to membership fees
-- ============================================================================
CREATE TABLE membership_payment (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_id INT NOT NULL UNIQUE,
    member_id INT NOT NULL,
    fee_type ENUM('Registration', 'Annual', 'Monthly', 'Renewal') NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_mp_payment FOREIGN KEY (payment_id)
        REFERENCES payment(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_mp_member FOREIGN KEY (member_id)
        REFERENCES member(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_membership_period CHECK (period_end > period_start)
) ENGINE=InnoDB;

CREATE INDEX idx_mp_member ON membership_payment(member_id);
CREATE INDEX idx_mp_period ON membership_payment(period_start, period_end);
CREATE INDEX idx_mp_fee_type ON membership_payment(fee_type);

-- ============================================================================
-- FINE_PAYMENT: Links payments specifically to late return fines
-- ============================================================================
CREATE TABLE fine_payment (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_id INT NOT NULL,
    loan_id INT NOT NULL,
    fine_calculated_date DATE NOT NULL,
    days_overdue INT NOT NULL,
    daily_rate DECIMAL(10,2) NOT NULL,
    total_fine DECIMAL(10,2) NOT NULL,
    amount_paid DECIMAL(10,2) NOT NULL,
    outstanding_balance DECIMAL(10,2) DEFAULT 0.00,
    waived_amount DECIMAL(10,2) DEFAULT 0.00,
    waived_by VARCHAR(100),
    waiver_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_fp_payment FOREIGN KEY (payment_id)
        REFERENCES payment(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_fp_loan FOREIGN KEY (loan_id)
        REFERENCES loan(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_days_overdue CHECK (days_overdue >= 0),
    CONSTRAINT chk_daily_rate CHECK (daily_rate >= 0),
    CONSTRAINT chk_total_fine CHECK (total_fine >= 0),
    CONSTRAINT chk_amount_paid CHECK (amount_paid >= 0),
    CONSTRAINT chk_outstanding CHECK (outstanding_balance >= 0),
    CONSTRAINT chk_waived CHECK (waived_amount >= 0)
) ENGINE=InnoDB;

CREATE INDEX idx_fp_loan ON fine_payment(loan_id);
CREATE INDEX idx_fp_date ON fine_payment(fine_calculated_date);

-- ============================================================================
-- PAYMENT_RECEIPT: Generates receipts for completed payments
-- ============================================================================
CREATE TABLE payment_receipt (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_id INT NOT NULL UNIQUE,
    receipt_number VARCHAR(50) UNIQUE NOT NULL,
    issued_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    issued_by VARCHAR(100),
    receipt_format ENUM('PDF', 'Printed', 'Email', 'SMS') DEFAULT 'Printed',
    is_duplicate BOOLEAN DEFAULT FALSE,
    original_receipt_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_receipt_payment FOREIGN KEY (payment_id)
        REFERENCES payment(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_receipt_original FOREIGN KEY (original_receipt_id)
        REFERENCES payment_receipt(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_receipt_number ON payment_receipt(receipt_number);
CREATE INDEX idx_receipt_date ON payment_receipt(issued_date);

-- ============================================================================
-- GRANT ACCESS TO THE GROUP USER
-- The 'group_four' user can access the database from anywhere 
-- to 'SELECT', 'INSERT' and 'UPDATE' records from the database
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON library_index_system.* TO 'group_four'@'%';


-- ============================================================================
-- LIBRARY SYSTEM - SAMPLE DATA INSERTION
-- Library Index System for Nigerian Libraries
-- ============================================================================

USE library_index_system;

-- ============================================================================
-- INSERT publisherS (International and Nigerian publishers)
-- ============================================================================

INSERT INTO publisher (`name`, country, established_year, website, contact_email, contact_phone, is_active) VALUES
-- International publishers
('Penguin Random House', 'USA', 1927, 'https://www.penguinrandomhouse.com', 'info@penguinrandomhouse.com', '12127829000', TRUE),
('Oxford University Press', 'UK', 1586, 'https://global.oup.com', 'enquiries@oup.com', '441865556767', TRUE),
('Macmillan publishers', 'UK', 1843, 'https://www.macmillan.com', 'info@macmillan.com', '442078334000', TRUE),
('Cambridge University Press', 'UK', 1534, 'https://www.cambridge.org', 'info@cambridge.org', '441223312393', TRUE),
('Pearson Education', 'UK', 1844, 'https://www.pearson.com', 'contact@pearson.com', '442070102000', TRUE),

-- Nigerian publishers
('Cassava Republic Press', 'Nigeria', 2006, 'https://www.cassavarepublic.biz', 'info@cassavarepublic.biz', '23412950620', TRUE),
('Farafina books', 'Nigeria', 2008, 'https://www.kachifo.com', 'info@kachifo.com', '23412707392', TRUE),
('Fourth Estate (Nigeria)', 'Nigeria', 1985, 'https://www.fourthestate.org', 'info@fourthestate.org', '2348033015533', TRUE),
('University Press PLC', 'Nigeria', 1960, 'https://www.universitypressplc.com', 'info@universitypressplc.com', '23412712931', TRUE),
('Spectrum books Limited', 'Nigeria', 1986, 'https://www.spectrumbooksonline.com', 'info@spectrumbooks.com', '23422411048', TRUE),
('CSS bookshops Limited', 'Nigeria', 1974, 'https://www.cssbookshops.com', 'info@cssbookshops.com', '23412631990', TRUE),
('Malthouse Press Limited', 'Nigeria', 1991, 'https://www.malthouselagos.com', 'info@malthouselagos.com', '23414930621', TRUE),
('Literamed Publications', 'Nigeria', 1988, 'https://www.literamed.com', 'info@literamed.com', '2348033045578', TRUE),
('Longman Nigeria', 'Nigeria', 1961, 'https://www.longmannigeria.com', 'info@longmannigeria.com', '23412802014', TRUE),
('Evans Brothers Nigeria', 'Nigeria', 1972, 'https://www.evansbrothers.com', 'nigeria@evansbrothers.com', '23412694611', TRUE);

-- ============================================================================
-- INSERT subjects (Nigerian curriculum and general subjects)
-- ============================================================================

INSERT INTO `subject` (subject_code, `name`, parent_subject_id, description, is_active) VALUES
-- Top-level subjects
('LIT', 'Literature', NULL, 'Literary works including African and world literature', TRUE),
('FIC', 'Fiction', NULL, 'Fictional works including novels and short stories', TRUE),
('HIS', 'History', NULL, 'Historical works and African history', TRUE),
('BIO', 'Biography', NULL, 'Life stories of notable individuals', TRUE),
('SCI', 'Science', NULL, 'Natural sciences and mathematics', TRUE),
('TECH', 'Technology', NULL, 'Applied sciences and technology', TRUE),
('EDU', 'Education', NULL, 'Educational and pedagogical works', TRUE),
('SOC', 'Social Sciences', NULL, 'Sociology, economics, and political science', TRUE),
('ART', 'Arts & Culture', NULL, 'Fine arts, music, and cultural studies', TRUE),
('REL', 'Religion', NULL, 'Religious and spiritual texts', TRUE),
('LAW', 'Law', NULL, 'Legal texts and constitutional studies', TRUE),
('BUS', 'Business', NULL, 'Business, management, and entrepreneurship', TRUE),

-- Sub-subjects
('AFLIT', 'African Literature', 1, 'Literature by African authors', TRUE),
('NIGLIT', 'Nigerian Literature', 1, 'Literature by Nigerian authors', TRUE),
('YORLIT', 'Yoruba Literature', 1, 'Literature in Yoruba language', TRUE),
('IGBLIT', 'Igbo Literature', 1, 'Literature in Igbo language', TRUE),
('HAUSLIT', 'Hausa Literature', 1, 'Literature in Hausa language', TRUE),
('AFHIST', 'African History', 3, 'History of African nations and peoples', TRUE),
('NIGHIST', 'Nigerian History', 3, 'History of Nigeria', TRUE),
('COMPSC', 'Computer Science', 6, 'Computing and information technology', TRUE),
('PHYS', 'Physics', 5, 'Physical sciences', TRUE),
('CHEM', 'Chemistry', 5, 'Chemical sciences', TRUE),
('BIOL', 'Biology', 5, 'Biological sciences', TRUE),
('MATH', 'Mathematics', 5, 'Mathematical sciences', TRUE),
('POLIT', 'Politics', 8, 'Political science and governance', TRUE),
('ECON', 'Economics', 8, 'Economic theory and development', TRUE);

-- ============================================================================
-- INSERT branchES (Nigerian Library branches)
-- ============================================================================

INSERT INTO branch (branch_code, `name`, address_line1, address_line2, city, state, country, phone, email, manager_name, seating_capacity, is_active, established_date) VALUES
-- Lagos State Libraries
('LAGOS01', 'Lagos Central Library', '27 Broad Street', 'Lagos Island', 'Lagos', 'Lagos State', 'Nigeria', '23412630905', 'central@lagoslibraries.ng', 'Adebayo Olumide', 250, TRUE, '1960-10-01'),
('LAGOS02', 'Ikeja branch Library', '12 Obafemi Awolowo Way', 'Ikeja GRA', 'Lagos', 'Lagos State', 'Nigeria', '23414970234', 'ikeja@lagoslibraries.ng', 'Chiamaka Okafor', 180, TRUE, '1985-06-15'),
('LAGOS03', 'Victoria Island Library', '1401 Ahmadu Bello Way', 'Victoria Island', 'Lagos', 'Lagos State', 'Nigeria', '23414612345', 'vi@lagoslibraries.ng', 'Fatima Abubakar', 150, TRUE, '2010-03-20'),
('LAGOS04', 'Yaba Technology Library', '34 Herbert Macaulay Street', 'Yaba', 'Lagos', 'Lagos State', 'Nigeria', '23418623456', 'yaba@lagoslibraries.ng', 'Emeka Nwosu', 200, TRUE, '2005-09-12'),

-- Abuja Libraries
('ABUJA01', 'National Library of Nigeria', 'Plot 274 Samuel Ademulegun Street', 'Central Business District', 'Abuja', 'FCT', 'Nigeria', '23492345678', 'info@nationallibrary.gov.ng', 'Dr. Amina Bello', 400, TRUE, '1964-11-06'),
('ABUJA02', 'Wuse District Library', '23 Adetokunbo Ademola Crescent', 'Wuse II', 'Abuja', 'FCT', 'Nigeria', '2348094612890', 'wuse@abujalibraries.ng', 'Ibrahim Hassan', 180, TRUE, '2000-05-15'),
('ABUJA03', 'Garki Community Library', '17 Tafawa Balewa Way', 'Garki Area 3', 'Abuja', 'FCT', 'Nigeria', '2348092349012', 'garki@abujalibraries.ng', 'Ngozi Mbah', 120, TRUE, '2008-11-22'),

-- Kano State Libraries
('KANO01', 'Kano State Library', '2 Murtala Mohammed Way', 'Nassarawa GRA', 'Kano', 'Kano State', 'Nigeria', '2348064631234', 'info@kanolibrary.ng', 'Musa Abdullahi', 200, TRUE, '1975-08-10'),
('KANO02', 'Bayero University Library', 'Gwarzo Road', 'BUK Campus', 'Kano', 'Kano State', 'Nigeria', '2348064666555', 'library@buk.edu.ng', 'Prof. Aisha Mahmud', 300, TRUE, '1977-12-03'),

-- Port Harcourt Libraries
('PHC01', 'Port Harcourt City Library', '22 Aba Road', 'Old GRA', 'Port Harcourt', 'Rivers State', 'Nigeria', '2349084230456', 'phc@riverslibraries.ng', 'Chidi Okonkwo', 150, TRUE, '1980-04-18'),
('PHC02', 'University of Port Harcourt Library', 'East-West Road', 'Choba Campus', 'Port Harcourt', 'Rivers State', 'Nigeria', '2348033344449', 'library@uniport.edu.ng', 'Dr. Grace Eze', 350, TRUE, '1975-11-15'),

-- Ibadan Libraries
('IBADAN01', 'Kenneth Dike Library UI', 'University of Ibadan', 'UI Campus', 'Ibadan', 'Oyo State', 'Nigeria', '23470281041100', 'library@ui.edu.ng', 'Prof. Oluwaseun Adeyemi', 450, TRUE, '1948-11-17'),
('IBADAN02', 'Bodija Public Library', '15 Secretariat Road', 'Bodija', 'Ibadan', 'Oyo State', 'Nigeria', '2349023152345', 'bodija@oyolibraries.ng', 'Folake Ajayi', 130, TRUE, '1995-07-08');

-- ============================================================================
-- INSERT authorS (Nigerian and African authors)
-- ============================================================================

INSERT INTO author (first_name, last_name, middle_name, birth_date, death_date, nationality, biography, website) VALUES
-- Legendary Nigerian authors
('Chinua', 'Achebe', NULL, '1930-11-16', '2013-03-21', 'Nigerian', 'Novelist, poet, and critic. author of Things Fall Apart, considered the founding father of modern African literature.', 'https://www.chinuaachebe.com'),
('Wole', 'Soyinka', NULL, '1934-07-13', NULL, 'Nigerian', 'Playwright, poet, and Nobel Prize winner. First African to win Nobel Prize in Literature (1986).', 'https://www.wolesoyinka.com'),
('Chimamanda', 'Adichie', 'Ngozi', '1977-09-15', NULL, 'Nigerian', 'Award-winning novelist and short story writer. author of Half of a Yellow Sun and Americanah.', 'https://www.chimamanda.com'),
('Ben', 'Okri', NULL, '1959-03-15', NULL, 'Nigerian', 'Poet and novelist, winner of the booker Prize for The Famished Road.', NULL),
('Buchi', 'Emecheta', NULL, '1944-07-21', '2017-01-25', 'Nigerian', 'Novelist known for The Joys of Motherhood and Second Class Citizen.', NULL),
('Cyprian', 'Ekwensi', NULL, '1921-09-26', '2007-11-04', 'Nigerian', 'Pioneer of modern Nigerian literature. author of People of the City and Jagua Nana.', NULL),
('Amos', 'Tutuola', NULL, '1920-06-20', '1997-06-08', 'Nigerian', 'author of The Palm-Wine Drinkard, wrote in a unique Nigerian English style.', NULL),
('Flora', 'Nwapa', NULL, '1931-01-13', '1993-10-16', 'Nigerian', 'First African woman novelist to be published internationally. author of Efuru.', NULL),
('Elechi', 'Amadi', NULL, '1934-05-12', '2016-06-29', 'Nigerian', 'Novelist and playwright. Known for The Concubine.', NULL),
('Sefi', 'Atta', NULL, '1964-01-01', NULL, 'Nigerian', 'Award-winning novelist and playwright. author of Everything Good Will Come.', NULL),

-- Contemporary Nigerian authors
('Teju', 'Cole', NULL, '1975-06-27', NULL, 'Nigerian-American', 'Photographer, writer, and art historian. author of Open City.', 'https://www.tejucole.com'),
('Helon', 'Habila', NULL, '1967-11-15', NULL, 'Nigerian', 'Novelist, poet, and professor. author of Waiting for an Angel.', NULL),
('Adaobi', 'Nwaubani', 'Tricia', '1976-01-11', NULL, 'Nigerian', 'Novelist and journalist. author of I Do Not Come to You by Chance.', NULL),
('Lola', 'Shoneyin', NULL, '1974-01-01', NULL, 'Nigerian', 'Poet and novelist. author of The Secret Lives of Baba Segi\'s Wives.', NULL),
('Chibundu', 'Onuzo', NULL, '1991-06-01', NULL, 'Nigerian', 'Novelist. author of The Spider King\'s Daughter.', NULL),

-- Other African authors
('Ngũgĩ', 'Thiong\'o', 'wa', '1938-01-05', NULL, 'Kenyan', 'Renowned novelist, playwright, and postcolonial theorist.', NULL), -- NOTE the escape character for: '
('Nadine', 'Gordimer', NULL, '1923-11-20', '2014-07-13', 'South African', 'Nobel Prize-winning novelist and political activist.', NULL),
('Ayi Kwei', 'Armah', NULL, '1939-10-28', NULL, 'Ghanaian', 'Novelist known for The Beautyful Ones Are Not Yet Born.', NULL),

-- International authors with Nigerian connections
('Chinelo', 'Okparanta', NULL, '1981-01-01', NULL, 'Nigerian-American', 'author of Under the Udala Trees.', NULL),
('NoViolet', 'Bulawayo', NULL, '1981-01-01', NULL, 'Zimbabwean', 'author of We Need New `name`s.', NULL);

-- ============================================================================
-- INSERT bookS (Nigerian and African Literature Focus)
-- ============================================================================

INSERT INTO book (isbn, title, subtitle, edition, publication_year, language, pages, format, description, publisher_id, is_active) VALUES
-- Chinua Achebe's Works
('978-0-385-47454-2', 'Things Fall Apart', NULL, NULL, 1958, 'English', 209, 'Paperback', 'A landmark novel telling the story of Okonkwo and the impact of British colonialism on Igbo society.', 1, TRUE),
('978-0-385-47455-9', 'No Longer at Ease', NULL, NULL, 1960, 'English', 169, 'Paperback', 'Story of Obi Okonkwo, grandson of Okonkwo, navigating modern Nigeria.', 1, TRUE),
('978-0-385-26045-3', 'Arrow of God', NULL, NULL, 1964, 'English', 230, 'Paperback', 'Set in colonial Nigeria during the 1920s.', 1, TRUE),
('978-0-385-26046-0', 'A Man of the People', NULL, NULL, 1966, 'English', 166, 'Paperback', 'Political satire about post-colonial Nigeria.', 1, TRUE),
('978-0-307-47390-3', 'There Was a Country', 'A Memoir', NULL, 2012, 'English', 333, 'Hardcover', 'Personal history of the Nigerian-Biafran War.', 1, TRUE),

-- Chimamanda Ngozi Adichie's Works
('978-1-400-09538-4', 'Half of a Yellow Sun', NULL, NULL, 2006, 'English', 433, 'Paperback', 'Epic novel about the Nigerian-Biafran War through the lives of five people.', 1, TRUE),
('978-0-307-45592-3', 'Americanah', NULL, NULL, 2013, 'English', 477, 'Hardcover', 'Story of young Nigerian woman navigating race in America.', 1, TRUE),
('978-1-400-03694-4', 'Purple Hibiscus', NULL, NULL, 2003, 'English', 307, 'Paperback', 'Coming-of-age story in postcolonial Nigeria.', 1, TRUE),
('978-0-008-11520-4', 'Dear Ijeawele', 'A Feminist Manifesto in Fifteen Suggestions', NULL, 2017, 'English', 80, 'Hardcover', 'Letter on raising a daughter as a feminist.', 7, TRUE),
('978-0-007-48998-6', 'We Should All Be Feminists', NULL, NULL, 2014, 'English', 52, 'Paperback', 'Adapted from her TEDx talk on feminism in Africa.', 7, TRUE),

-- Wole Soyinka's Works
('978-0-413-69330-0', 'Death and the King\'s Horseman', NULL, NULL, 1975, 'English', 96, 'Paperback', 'Play based on a true incident in colonial Nigeria.', 3, TRUE),
('978-0-394-72019-4', 'Aké', 'The Years of Childhood', NULL, 1981, 'English', 230, 'Paperback', 'Autobiographical account of Soyinka\'s childhood in Abeokuta.', 1, TRUE),
('978-0-679-73240-0', 'The Interpreters', NULL, NULL, 1965, 'English', 253, 'Paperback', 'Novel about five Nigerian intellectuals in postcolonial Nigeria.', 1, TRUE),

-- Ben Okri's Works
('978-0-385-42550-5', 'The Famished Road', NULL, NULL, 1991, 'English', 500, 'Paperback', 'booker Prize-winning magical realist novel.', 1, TRUE),
('978-0-385-42034-0', 'Songs of Enchantment', NULL, NULL, 1993, 'English', 304, 'Paperback', 'Sequel to The Famished Road.', 1, TRUE),
('978-1-784-97267-3', 'The Freedom Artist', NULL, NULL, 2019, 'English', 240, 'Hardcover', 'Novel about imprisoned artists and the power of creativity.', 6, TRUE),

-- Buchi Emecheta's Works
('978-0-807-61313-5', 'The Joys of Motherhood', NULL, NULL, 1979, 'English', 224, 'Paperback', 'Story of Nigerian woman in Lagos struggling with motherhood.', 1, TRUE),
('978-0-807-61295-4', 'Second Class Citizen', NULL, NULL, 1974, 'English', 192, 'Paperback', 'Semi-autobiographical novel about Nigerian immigrant in London.', 1, TRUE),

-- Other Nigerian Literature
('978-0-393-32045-5', 'The Palm-Wine Drinkard', NULL, NULL, 1952, 'English', 130, 'Paperback', 'Amos Tutuola\'s groundbreaking work of Nigerian folklore.', 1, TRUE),
('978-0-435-90524-3', 'Efuru', NULL, NULL, 1966, 'English', 281, 'Paperback', 'Flora Nwapa\'s pioneering novel about an Igbo woman.', 14, TRUE),
('978-0-435-90525-0', 'The Concubine', NULL, NULL, 1966, 'English', 216, 'Paperback', 'Elechi Amadi\'s tragic love story in rural Nigeria.', 14, TRUE),
('978-1-933-35416-8', 'Everything Good Will Come', NULL, NULL, 2005, 'English', 319, 'Paperback', 'Sefi Atta\'s coming-of-age novel in Lagos.', 6, TRUE),
('978-0-812-97180-8', 'Open City', NULL, NULL, 2011, 'English', 259, 'Hardcover', 'Teju Cole\'s debut novel about a Nigerian doctor in New York.', 1, TRUE),
('978-0-393-32847-5', 'Waiting for an Angel', NULL, NULL, 2002, 'English', 229, 'Paperback', 'Helon Habila\'s novel about military dictatorship in Nigeria.', 1, TRUE),
('978-0-297-85534-9', 'I Do Not Come to You by Chance', NULL, NULL, 2009, 'English', 310, 'Paperback', 'Adaobi Nwaubani\'s satire on Nigerian email scammers.', 7, TRUE),
('978-0-304-36632-2', 'The Secret Lives of Baba Segi\'s Wives', NULL, NULL, 2010, 'English', 248, 'Paperback', 'Lola Shoneyin\'s novel about polygamy in modern Nigeria.', 6, TRUE),
('978-0-571-27700-4', 'The Spider King\'s Daughter', NULL, NULL, 2012, 'English', 304, 'Paperback', 'Chibundu Onuzo\'s debut novel set in contemporary Lagos.', 7, TRUE),

-- Other African Literature
('978-0-143-10664-1', 'Weep Not, Child', NULL, NULL, 1964, 'English', 136, 'Paperback', 'Ngugi wa Thiong\'o\'s first novel about Mau Mau Uprising in Kenya.', 1, TRUE),
('978-0-385-26060-6', 'The Beautyful Ones Are Not Yet Born', NULL, NULL, 1968, 'English', 183, 'Paperback', 'Ayi Kwei Armah\'s novel about corruption in post-independence Ghana.', 1, TRUE),
('978-0-316-21179-1', 'Under the Udala Trees', NULL, NULL, 2015, 'English', 337, 'Hardcover', 'Chinelo Okparanta\'s novel about forbidden love during Biafran War.', 7, TRUE),
('978-0-316-23040-2', 'We Need New `name`s', NULL, NULL, 2013, 'English', 304, 'Hardcover', 'NoViolet Bulawayo\'s debut about Zimbabwean girl\'s journey.', 7, TRUE),

-- Nigerian History and Non-Fiction
('978-014-101-820-6', 'The Trouble with Nigeria', NULL, NULL, 1983, 'English', 69, 'Paperback', 'Achebe\'s essay on Nigeria\'s political problems.', 9, TRUE),
('978-019-827-984-5', 'Nigerian History and Culture', NULL, NULL, 2010, 'English', 350, 'Hardcover', 'Comprehensive overview of Nigerian history from pre-colonial to modern times.', 2, TRUE),
('978-978-052-734-2', 'The History of West Africa', NULL, 'Revised Edition', 2015, 'English', 450, 'Hardcover', 'Detailed history of West African civilizations and colonial period.', 9, TRUE),

-- Academic books
('978-978-234-567-8', 'Introduction to Computer Science', 'Nigerian Edition', '2nd Edition', 2020, 'English', 520, 'Paperback', 'Computer science fundamentals with Nigerian context and examples.', 10, TRUE),
('978-978-345-678-9', 'Advanced Mathematics for Nigerian Students', 'WAEC & JAMB', '3rd Edition', 2021, 'English', 680, 'Paperback', 'Comprehensive mathematics textbook aligned with Nigerian curriculum.', 10, TRUE),
('978-978-456-789-0', 'Physics for Senior Secondary Schools', NULL, '4th Edition', 2019, 'English', 590, 'Paperback', 'Physics textbook meeting WAEC standards.', 14, TRUE),
('978-978-567-890-1', 'Chemistry Practical Manual', NULL, NULL, 2020, 'English', 280, 'Paperback', 'Laboratory guide for Nigerian secondary schools.', 14, TRUE),

-- Business and Economics
('978-978-678-901-2', 'Entrepreneurship in Nigeria', 'Strategies for Success', NULL, 2018, 'English', 385, 'Paperback', 'Guide to starting and running businesses in Nigerian economy.', 11, TRUE),
('978-978-789-012-3', 'Nigerian Economy', 'Past, Present, and Future', '2nd Edition', 2019, 'English', 420, 'Hardcover', 'Analysis of Nigerian economic development and challenges.', 9, TRUE);

-- ============================================================================
-- INSERT book-author RELATIONSHIPS
-- ============================================================================

INSERT INTO book_author (book_id, author_id, author_sequence, contribution_type) VALUES
-- Chinua Achebe's books (author_id = 1)
(1, 1, 1, 'Primary author'),
(2, 1, 1, 'Primary author'),
(3, 1, 1, 'Primary author'),
(4, 1, 1, 'Primary author'),
(5, 1, 1, 'Primary author'),
(31, 1, 1, 'Primary author'),

-- Chimamanda Ngozi Adichie's books (author_id = 3)
(6, 3, 1, 'Primary author'),
(7, 3, 1, 'Primary author'),
(8, 3, 1, 'Primary author'),
(9, 3, 1, 'Primary author'),
(10, 3, 1, 'Primary author'),

-- Wole Soyinka's books (author_id = 2)
(11, 2, 1, 'Primary author'),
(12, 2, 1, 'Primary author'),
(13, 2, 1, 'Primary author'),

-- Ben Okri's books (author_id = 4)
(14, 4, 1, 'Primary author'),
(15, 4, 1, 'Primary author'),
(16, 4, 1, 'Primary author'),

-- Buchi Emecheta's books (author_id = 5)
(17, 5, 1, 'Primary author'),
(18, 5, 1, 'Primary author'),

-- Other Nigerian authors
(19, 7, 1, 'Primary author'),  -- Amos Tutuola
(20, 8, 1, 'Primary author'),  -- Flora Nwapa
(21, 9, 1, 'Primary author'),  -- Elechi Amadi
(22, 10, 1, 'Primary author'), -- Sefi Atta
(23, 11, 1, 'Primary author'), -- Teju Cole
(24, 12, 1, 'Primary author'), -- Helon Habila
(25, 13, 1, 'Primary author'), -- Adaobi Nwaubani
(26, 14, 1, 'Primary author'), -- Lola Shoneyin
(27, 15, 1, 'Primary author'), -- Chibundu Onuzo

-- Other African authors
(28, 16, 1, 'Primary author'), -- Ngugi wa Thiong'o
(29, 18, 1, 'Primary author'), -- Ayi Kwei Armah
(30, 19, 1, 'Primary author'), -- Chinelo Okparanta
(31, 20, 1, 'Primary author'); -- NoViolet Bulawayo

-- ============================================================================
-- INSERT book-`subject` RELATIONSHIPS
-- ============================================================================

INSERT INTO book_subject (book_id, subject_id, is_primary_subject, assigned_date, assigned_by) VALUES
-- Things Fall Apart
(1, 2, TRUE, '2024-01-15', 'System'),
(1, 13, FALSE, '2024-01-15', 'System'),
(1, 14, FALSE, '2024-01-15', 'System'),

-- No Longer at Ease
(2, 2, TRUE, '2024-01-15', 'System'),
(2, 14, FALSE, '2024-01-15', 'System'),

-- Arrow of God
(3, 2, TRUE, '2024-01-15', 'System'),
(3, 14, FALSE, '2024-01-15', 'System'),

-- A Man of the People
(4, 2, TRUE, '2024-01-15', 'System'),
(4, 24, FALSE, '2024-01-15', 'System'),

-- There Was a Country
(5, 4, TRUE, '2024-01-15', 'System'),
(5, 3, FALSE, '2024-01-15', 'System'),
(5, 19, FALSE, '2024-01-15', 'System'),

-- Half of a Yellow Sun
(6, 2, TRUE, '2024-01-15', 'System'),
(6, 3, FALSE, '2024-01-15', 'System'),
(6, 19, FALSE, '2024-01-15', 'System'),

-- Americanah
(7, 2, TRUE, '2024-01-15', 'System'),
(7, 8, FALSE, '2024-01-15', 'System'),

-- Purple Hibiscus
(8, 2, TRUE, '2024-01-15', 'System'),
(8, 14, FALSE, '2024-01-15', 'System'),

-- Dear Ijeawele
(9, 8, TRUE, '2024-01-15', 'System'),
(9, 7, FALSE, '2024-01-15', 'System'),

-- We Should All Be Feminists
(10, 8, TRUE, '2024-01-15', 'System'),
(10, 7, FALSE, '2024-01-15', 'System'),

-- Death and the King's Horseman
(11, 1, TRUE, '2024-01-15', 'System'),
(11, 9, FALSE, '2024-01-15', 'System'),

-- Aké: The Years of Childhood
(12, 4, TRUE, '2024-01-15', 'System'),
(12, 14, FALSE, '2024-01-15', 'System'),

-- The Interpreters
(13, 2, TRUE, '2024-01-15', 'System'),
(13, 14, FALSE, '2024-01-15', 'System'),

-- The Famished Road
(14, 2, TRUE, '2024-01-15', 'System'),
(14, 13, FALSE, '2024-01-15', 'System'),

-- Songs of Enchantment
(15, 2, TRUE, '2024-01-15', 'System'),
(15, 13, FALSE, '2024-01-15', 'System'),

-- The Freedom Artist
(16, 2, TRUE, '2024-01-15', 'System'),
(16, 9, FALSE, '2024-01-15', 'System'),

-- The Joys of Motherhood
(17, 2, TRUE, '2024-01-15', 'System'),
(17, 14, FALSE, '2024-01-15', 'System'),
(17, 8, FALSE, '2024-01-15', 'System'),

-- Second Class Citizen
(18, 2, TRUE, '2024-01-15', 'System'),
(18, 14, FALSE, '2024-01-15', 'System'),

-- The Palm-Wine Drinkard
(19, 2, TRUE, '2024-01-15', 'System'),
(19, 14, FALSE, '2024-01-15', 'System'),

-- Efuru
(20, 2, TRUE, '2024-01-15', 'System'),
(20, 14, FALSE, '2024-01-15', 'System'),

-- The Concubine
(21, 2, TRUE, '2024-01-15', 'System'),
(21, 14, FALSE, '2024-01-15', 'System'),

-- Everything Good Will Come
(22, 2, TRUE, '2024-01-15', 'System'),
(22, 14, FALSE, '2024-01-15', 'System'),

-- Open City
(23, 2, TRUE, '2024-01-15', 'System'),
(23, 8, FALSE, '2024-01-15', 'System'),

-- Waiting for an Angel
(24, 2, TRUE, '2024-01-15', 'System'),
(24, 14, FALSE, '2024-01-15', 'System'),
(24, 24, FALSE, '2024-01-15', 'System'),

-- I Do Not Come to You by Chance
(25, 2, TRUE, '2024-01-15', 'System'),
(25, 14, FALSE, '2024-01-15', 'System'),

-- The Secret Lives of Baba Segi's Wives
(26, 2, TRUE, '2024-01-15', 'System'),
(26, 14, FALSE, '2024-01-15', 'System'),
(26, 8, FALSE, '2024-01-15', 'System'),

-- The Spider King's Daughter
(27, 2, TRUE, '2024-01-15', 'System'),
(27, 14, FALSE, '2024-01-15', 'System'),

-- Weep Not, Child
(28, 2, TRUE, '2024-01-15', 'System'),
(28, 13, FALSE, '2024-01-15', 'System'),
(28, 3, FALSE, '2024-01-15', 'System'),

-- The Beautyful Ones Are Not Yet Born
(29, 2, TRUE, '2024-01-15', 'System'),
(29, 13, FALSE, '2024-01-15', 'System'),
(29, 24, FALSE, '2024-01-15', 'System'),

-- Under the Udala Trees
(30, 2, TRUE, '2024-01-15', 'System'),
(30, 19, FALSE, '2024-01-15', 'System'),

-- We Need New `name`s
(31, 2, TRUE, '2024-01-15', 'System'),
(31, 13, FALSE, '2024-01-15', 'System'),

-- The Trouble with Nigeria
(32, 24, TRUE, '2024-01-15', 'System'),
(32, 19, FALSE, '2024-01-15', 'System'),
(32, 8, FALSE, '2024-01-15', 'System'),

-- Nigerian History and Culture
(33, 3, TRUE, '2024-01-15', 'System'),
(33, 19, FALSE, '2024-01-15', 'System'),

-- The History of West Africa
(34, 3, TRUE, '2024-01-15', 'System'),
(34, 18, FALSE, '2024-01-15', 'System'),

-- Introduction to Computer Science
(35, 20, TRUE, '2024-01-15', 'System'),
(35, 6, FALSE, '2024-01-15', 'System'),

-- Advanced Mathematics
(36, 24, TRUE, '2024-01-15', 'System'),
(36, 5, FALSE, '2024-01-15', 'System'),

-- Physics for Senior Secondary Schools
(37, 21, TRUE, '2024-01-15', 'System'),
(37, 5, FALSE, '2024-01-15', 'System'),

-- Chemistry Practical Manual
(38, 22, TRUE, '2024-01-15', 'System'),
(38, 5, FALSE, '2024-01-15', 'System'),

-- Entrepreneurship in Nigeria
(39, 12, TRUE, '2024-01-15', 'System'),
(39, 25, FALSE, '2024-01-15', 'System'),

-- Nigerian Economy
(40, 25, TRUE, '2024-01-15', 'System'),
(40, 8, FALSE, '2024-01-15', 'System'),
(40, 19, FALSE, '2024-01-15', 'System');

UPDATE book_subject
SET assigned_date = DATE_ADD(assigned_date, INTERVAL 1 YEAR)
WHERE book_id >= 0;

-- ============================================================================
-- INSERT book COPIES (Distributed across Nigerian branches)
-- ============================================================================

INSERT INTO book_copy (book_id, branch_id, barcode, acquisition_date, acquisition_cost, condition_status, availability_status, shelf_location) VALUES
-- Things Fall Apart - Popular book, multiple copies across branches
(1, 1, 'NLC001000001', '2020-01-15', 2500.00, 'Good', 'Available', 'FIC-ACH-01'),
(1, 1, 'NLC001000002', '2020-01-15', 2500.00, 'Excellent', 'Available', 'FIC-ACH-01'),
(1, 2, 'NLC001000003', '2020-03-20', 2500.00, 'Good', 'Available', 'FIC-ACH-01'),
(1, 3, 'NLC001000004', '2020-05-10', 2800.00, 'Excellent', 'Available', 'FIC-ACH-01'),
(1, 5, 'NLC001000005', '2019-11-05', 2300.00, 'Fair', 'Available', 'FIC-ACH-01'),
(1, 8, 'NLC001000006', '2021-02-14', 2700.00, 'Excellent', 'Available', 'FIC-ACH-01'),
(1, 11, 'NLC001000007', '2018-09-20', 2200.00, 'Good', 'Available', 'FIC-ACH-01'),
(1, 12, 'NLC001000008', '2020-07-18', 2600.00, 'Excellent', 'Available', 'FIC-ACH-01'),

-- No Longer at Ease
(2, 1, 'NLC002000001', '2020-02-20', 2300.00, 'Good', 'Available', 'FIC-ACH-02'),
(2, 2, 'NLC002000002', '2020-04-15', 2400.00, 'Excellent', 'Available', 'FIC-ACH-02'),
(2, 5, 'NLC002000003', '2020-06-10', 2500.00, 'Good', 'Available', 'FIC-ACH-02'),
(2, 11, 'NLC002000004', '2019-12-05', 2200.00, 'Fair', 'Available', 'FIC-ACH-02'),

-- Arrow of God
(3, 1, 'NLC003000001', '2020-01-30', 2600.00, 'Excellent', 'Available', 'FIC-ACH-03'),
(3, 5, 'NLC003000002', '2020-03-25', 2700.00, 'Good', 'Available', 'FIC-ACH-03'),
(3, 8, 'NLC003000003', '2020-05-20', 2800.00, 'Excellent', 'Available', 'FIC-ACH-03'),

-- Half of a Yellow Sun - Very popular
(6, 1, 'NLC006000001', '2021-01-10', 4500.00, 'Excellent', 'Available', 'FIC-ADI-01'),
(6, 1, 'NLC006000002', '2021-01-10', 4500.00, 'Excellent', 'Available', 'FIC-ADI-01'),
(6, 2, 'NLC006000003', '2021-02-15', 4600.00, 'Good', 'Available', 'FIC-ADI-01'),
(6, 3, 'NLC006000004', '2021-03-20', 4800.00, 'Excellent', 'Available', 'FIC-ADI-01'),
(6, 5, 'NLC006000005', '2021-01-25', 4400.00, 'Good', 'Available', 'FIC-ADI-01'),
(6, 8, 'NLC006000006', '2021-04-10', 4700.00, 'Excellent', 'Available', 'FIC-ADI-01'),
(6, 11, 'NLC006000007', '2020-11-15', 4300.00, 'Good', 'Available', 'FIC-ADI-01'),

-- Americanah - Very popular
(7, 1, 'NLC007000001', '2022-01-05', 5200.00, 'Excellent', 'Available', 'FIC-ADI-02'),
(7, 1, 'NLC007000002', '2022-01-05', 5200.00, 'Excellent', 'Available', 'FIC-ADI-02'),
(7, 2, 'NLC007000003', '2022-02-10', 5300.00, 'Good', 'Available', 'FIC-ADI-02'),
(7, 3, 'NLC007000004', '2022-03-15', 5500.00, 'Excellent', 'Available', 'FIC-ADI-02'),
(7, 5, 'NLC007000005', '2021-12-20', 5100.00, 'Good', 'Available', 'FIC-ADI-02'),
(7, 8, 'NLC007000006', '2022-04-05', 5400.00, 'Excellent', 'Available', 'FIC-ADI-02'),

-- Purple Hibiscus
(8, 1, 'NLC008000001', '2021-06-15', 3800.00, 'Excellent', 'Available', 'FIC-ADI-03'),
(8, 2, 'NLC008000002', '2021-07-20', 3900.00, 'Good', 'Available', 'FIC-ADI-03'),
(8, 3, 'NLC008000003', '2021-08-10', 4000.00, 'Excellent', 'Available', 'FIC-ADI-03'),
(8, 5, 'NLC008000004', '2021-05-25', 3700.00, 'Good', 'Available', 'FIC-ADI-03'),
(8, 11, 'NLC008000005', '2021-09-14', 4100.00, 'Excellent', 'Available', 'FIC-ADI-03'),

-- We Should All Be Feminists
(10, 1, 'NLC010000001', '2022-03-08', 1800.00, 'Excellent', 'Available', 'SOC-ADI-01'),
(10, 2, 'NLC010000002', '2022-03-08', 1800.00, 'Excellent', 'Available', 'SOC-ADI-01'),
(10, 3, 'NLC010000003', '2022-04-12', 1900.00, 'Good', 'Available', 'SOC-ADI-01'),
(10, 5, 'NLC010000004', '2022-02-20', 1700.00, 'Good', 'Available', 'SOC-ADI-01'),

-- Death and the King's Horseman (Soyinka)
(11, 1, 'NLC011000001', '2020-10-01', 2800.00, 'Good', 'Available', 'LIT-SOY-01'),
(11, 5, 'NLC011000002', '2020-11-15', 2900.00, 'Excellent', 'Available', 'LIT-SOY-01'),
(11, 11, 'NLC011000003', '2020-09-20', 2700.00, 'Good', 'Available', 'LIT-SOY-01'),

-- The Famished Road (Okri)
(14, 1, 'NLC014000001', '2021-04-10', 4200.00, 'Excellent', 'Available', 'FIC-OKR-01'),
(14, 2, 'NLC014000002', '2021-05-15', 4300.00, 'Good', 'Available', 'FIC-OKR-01'),
(14, 5, 'NLC014000003', '2021-03-25', 4100.00, 'Good', 'Available', 'FIC-OKR-01'),
(14, 11, 'NLC014000004', '2021-06-20', 4400.00, 'Excellent', 'Available', 'FIC-OKR-01'),

-- The Joys of Motherhood (Emecheta)
(17, 1, 'NLC017000001', '2020-06-15', 3200.00, 'Good', 'Available', 'FIC-EME-01'),
(17, 2, 'NLC017000002', '2020-07-20', 3300.00, 'Excellent', 'Available', 'FIC-EME-01'),
(17, 5, 'NLC017000003', '2020-05-30', 3100.00, 'Fair', 'Available', 'FIC-EME-01'),

-- The Palm-Wine Drinkard (Tutuola)
(19, 1, 'NLC019000001', '2019-08-10', 2400.00, 'Fair', 'Available', 'FIC-TUT-01'),
(19, 5, 'NLC019000002', '2019-09-15', 2500.00, 'Good', 'Available', 'FIC-TUT-01'),
(19, 11, 'NLC019000003', '2019-07-25', 2300.00, 'Fair', 'Available', 'FIC-TUT-01'),

-- Nigerian History and Culture
(33, 1, 'NLC033000001', '2022-01-15', 8500.00, 'Excellent', 'Available', 'HIS-NIG-01'),
(33, 5, 'NLC033000002', '2022-02-20', 8700.00, 'Excellent', 'Available', 'HIS-NIG-01'),
(33, 8, 'NLC033000003', '2022-03-10', 8600.00, 'Good', 'Available', 'HIS-NIG-01'),
(33, 11, 'NLC033000004', '2021-12-05', 8400.00, 'Good', 'Available', 'HIS-NIG-01'),

-- Introduction to Computer Science
(35, 1, 'NLC035000001', '2023-01-10', 12000.00, 'Excellent', 'Available', 'TECH-CS-01'),
(35, 2, 'NLC035000002', '2023-01-10', 12000.00, 'Excellent', 'Available', 'TECH-CS-01'),
(35, 4, 'NLC035000003', '2023-02-15', 12500.00, 'Excellent', 'Available', 'TECH-CS-01'),
(35, 5, 'NLC035000004', '2023-01-20', 12200.00, 'Good', 'Available', 'TECH-CS-01'),
(35, 9, 'NLC035000005', '2023-03-05', 12300.00, 'Excellent', 'Available', 'TECH-CS-01'),

-- Advanced Mathematics
(36, 1, 'NLC036000001', '2023-02-01', 15000.00, 'Excellent', 'Available', 'MATH-ADV-01'),
(36, 2, 'NLC036000002', '2023-02-01', 15000.00, 'Excellent', 'Available', 'MATH-ADV-01'),
(36, 5, 'NLC036000003', '2023-03-10', 15500.00, 'Good', 'Available', 'MATH-ADV-01'),
(36, 8, 'NLC036000004', '2023-02-15', 15200.00, 'Excellent', 'Available', 'MATH-ADV-01'),
(36, 9, 'NLC036000005', '2023-03-20', 15400.00, 'Excellent', 'Available', 'MATH-ADV-01'),

-- Physics for Senior Secondary Schools
(37, 2, 'NLC037000001', '2023-01-15', 13500.00, 'Excellent', 'Available', 'SCI-PHY-01'),
(37, 5, 'NLC037000002', '2023-02-20', 13800.00, 'Good', 'Available', 'SCI-PHY-01'),
(37, 8, 'NLC037000003', '2023-01-25', 13600.00, 'Excellent', 'Available', 'SCI-PHY-01'),
(37, 9, 'NLC037000004', '2023-03-10', 13900.00, 'Excellent', 'Available', 'SCI-PHY-01'),

-- Entrepreneurship in Nigeria
(39, 1, 'NLC039000001', '2022-06-15', 9500.00, 'Excellent', 'Available', 'BUS-ENT-01'),
(39, 2, 'NLC039000002', '2022-07-20', 9700.00, 'Good', 'Available', 'BUS-ENT-01'),
(39, 3, 'NLC039000003', '2022-08-10', 9800.00, 'Excellent', 'Available', 'BUS-ENT-01'),
(39, 5, 'NLC039000004', '2022-06-25', 9400.00, 'Good', 'Available', 'BUS-ENT-01');

UPDATE book_copy
SET acquisition_date = DATE_ADD(acquisition_date, INTERVAL 2 YEAR)
WHERE book_id >= 0;

-- ============================================================================
-- INSERT memberS (Nigerian library members)
-- ============================================================================

INSERT INTO `member` (membership_number, first_name, middle_name, last_name, date_of_birth, email, phone, address_line1, address_line2, city, state, country, home_branch_id, membership_type, membership_start_date, membership_expiry_date, is_active) VALUES
-- Lagos members
('MEM2024001', 'Oluwaseun', 'Adeola', 'Adeyemi', '1985-03-15', 'seun.adeyemi@gmail.com', '2348034567890', '45 Allen Avenue', 'Ikeja', 'Lagos', 'Lagos State', 'Nigeria', 2, 'Premium', '2024-01-15', '2025-01-15', TRUE),
('MEM2024002', 'Chiamaka', 'Nneoma', 'Okafor', '1992-07-22', 'chiamaka.okafor@yahoo.com', '2348102345678', '12 Admiralty Way', 'Lekki Phase 1', 'Lagos', 'Lagos State', 'Nigeria', 3, 'Standard', '2024-02-10', '2025-02-10', TRUE),
('MEM2024003', 'Ibrahim', 'Musa', 'Hassan', '1978-11-08', 'ibrahim.hassan@outlook.com', '2348078901234', '78 Broad Street', 'Lagos Island', 'Lagos', 'Lagos State', 'Nigeria', 1, 'Standard', '2023-11-20', '2024-11-20', TRUE),
('MEM2024004', 'Folake', 'Omolara', 'Adebayo', '2005-05-12', 'folake.adebayo@student.edu.ng', '2349015678901', '34 Herbert Macaulay', 'Yaba', 'Lagos', 'Lagos State', 'Nigeria', 4, 'Student', '2024-03-01', '2025-03-01', TRUE),
('MEM2024005', 'Emeka', 'Chukwudi', 'Nwosu', '1968-09-25', 'emeka.nwosu@gmail.com', '2348061234567', '56 Awolowo Road', 'Ikoyi', 'Lagos', 'Lagos State', 'Nigeria', 1, 'Senior', '2023-09-15', '2024-09-15', TRUE),
('MEM2024021', 'Tunde', 'Babatunde', 'Olaleye', '1996-02-11', 'tunde.olaleye@gmail.com', '2348126789012', '90 Opebi Road', 'Ikeja', 'Lagos', 'Lagos State', 'Nigeria', 2, 'Standard', '2024-02-25', '2025-02-25', TRUE),
('MEM2024022', 'Zainab', 'Khadija', 'Yusuf', '1998-10-30', 'zainab.yusuf@yahoo.com', '2348182345678', '15 Ozumba Mbadiwe', 'Victoria Island', 'Lagos', 'Lagos State', 'Nigeria', 3, 'Standard', '2024-03-15', '2025-03-15', TRUE),
('MEM2024023', 'Ifeanyi', 'Chidi', 'Nwankwo', '2000-04-25', 'ifeanyi.nwankwo@student.edu.ng', '2347095678901', '28 Akoka Road', 'Akoka', 'Lagos', 'Lagos State', 'Nigeria', 1, 'Student', '2024-01-20', '2025-01-20', TRUE),
('MEM2024024', 'Adeola', 'Funmilayo', 'Babajide', '1983-07-14', 'adeola.babajide@gmail.com', '2348048901234', '56 Toyin Street', 'Ikeja', 'Lagos', 'Lagos State', 'Nigeria', 2, 'Premium', '2024-02-10', '2025-02-10', TRUE),
('MEM2024025', 'Kelechi', 'Nkechi', 'Udeh', '1997-09-05', 'kelechi.udeh@outlook.com', '2348193456789', '102 Apapa Road', 'Ebute Metta', 'Lagos', 'Lagos State', 'Nigeria', 1, 'Standard', '2024-03-20', '2025-03-20', TRUE),

-- Abuja members
('MEM2024006', 'Aisha', 'Fatima', 'Bello', '1990-01-18', 'aisha.bello@yahoo.com', '2348093456789', '23 Gana Street', 'Maitama', 'Abuja', 'FCT', 'Nigeria', 5, 'Premium', '2024-01-20', '2025-01-20', TRUE),
('MEM2024007', 'Chinedu', 'Obinna', 'Okoro', '1987-06-30', 'chinedu.okoro@outlook.com', '2348136789012', '45 Adetokunbo Ademola', 'Wuse II', 'Abuja', 'FCT', 'Nigeria', 6, 'Standard', '2024-02-15', '2025-02-15', TRUE),
('MEM2024008', 'Blessing', 'Chioma', 'Eze', '2003-12-05', 'blessing.eze@student.edu.ng', '2347052345678', '12 Gimbiya Street', 'Garki Area 11', 'Abuja', 'FCT', 'Nigeria', 7, 'Student', '2024-01-10', '2025-01-10', TRUE),
('MEM2024009', 'Mohammed', 'Aliyu', 'Abdullahi', '1995-04-14', 'mohammed.abdullahi@gmail.com', '2348089012345', '67 Aminu Kano Crescent', 'Wuse II', 'Abuja', 'FCT', 'Nigeria', 6, 'Standard', '2023-12-01', '2024-12-01', TRUE),
('MEM2024010', 'Ngozi', 'Amarachi', 'Okonkwo', '1982-08-27', 'ngozi.okonkwo@yahoo.com', '2348164567890', '89 Michael Okpara Street', 'Wuse Zone 7', 'Abuja', 'FCT', 'Nigeria', 5, 'Premium', '2024-03-05', '2025-03-05', TRUE),
('MEM2024026', 'Suleiman', 'Usman', 'Danjuma', '1992-11-28', 'suleiman.danjuma@gmail.com', '2348032345678', '45 Constitution Avenue', 'Central Business District', 'Abuja', 'FCT', 'Nigeria', 5, 'Standard', '2024-01-05', '2025-01-05', TRUE),
('MEM2024027', 'Esther', 'Oluchi', 'Nwachukwu', '1999-03-17', 'esther.nwachukwu@student.edu.ng', '2347026789012', '23 Kashim Ibrahim Way', 'Asokoro', 'Abuja', 'FCT', 'Nigeria', 6, 'Student', '2024-02-12', '2025-02-12', TRUE),
('MEM2024028', 'Damilola', 'Ayomide', 'Adeyinka', '1987-05-09', 'dami.adeyinka@yahoo.com', '2348209012345', '78 Aguiyi Ironsi Way', 'Maitama', 'Abuja', 'FCT', 'Nigeria', 5, 'Premium', '2024-03-08', '2025-03-08', TRUE),
('MEM2024029', 'Precious', 'Chinonso', 'Onyeka', '2003-08-21', 'precious.onyeka@student.edu.ng', '2347101234567', '34 Ralph Shodeinde', 'Central Area', 'Abuja', 'FCT', 'Nigeria', 7, 'Student', '2024-01-18', '2025-01-18', TRUE),
('MEM2024030', 'Abdulrahman', 'Kabir', 'Sanusi', '1980-12-03', 'abdulrahman.sanusi@outlook.com', '2348074567890', '90 Oladipo Diya Way', 'Gudu', 'Abuja', 'FCT', 'Nigeria', 6, 'Standard', '2023-11-25', '2024-11-25', TRUE),

-- Kano members
('MEM2024011', 'Fatima', 'Halima', 'Suleiman', '1993-02-14', 'fatima.suleiman@gmail.com', '2348112345678', '15 Zaria Road', 'Nassarawa GRA', 'Kano', 'Kano State', 'Nigeria', 8, 'Standard', '2024-01-25', '2025-01-25', TRUE),
('MEM2024012', 'Yusuf', 'Ahmad', 'Mahmud', '2002-10-20', 'yusuf.mahmud@student.edu.ng', '2347067890123', '23 Gwarzo Road', 'BUK Campus', 'Kano', 'Kano State', 'Nigeria', 9, 'Student', '2024-02-01', '2025-02-01', TRUE),
('MEM2024013', 'Hauwa', 'Abubakar', 'Ibrahim', '1988-07-08', 'hauwa.ibrahim@yahoo.com', '2348145678901', '45 Zoo Road', 'Kano Municipal', 'Kano', 'Kano State', 'Nigeria', 8, 'Standard', '2023-11-10', '2024-11-10', TRUE),

-- Port Harcourt members
('MEM2024014', 'Chibueze', 'Emmanuel', 'Obi', '1991-05-16', 'chibueze.obi@gmail.com', '2348023456789', '34 Aba Road', 'Old GRA', 'Port Harcourt', 'Rivers State', 'Nigeria', 10, 'Standard', '2024-02-20', '2025-02-20', TRUE),
('MEM2024015', 'Amarachi', 'Grace', 'Nnamani', '2004-11-03', 'amarachi.nnamani@student.edu.ng', '2347089012345', '12 East-West Road', 'Choba', 'Port Harcourt', 'Rivers State', 'Nigeria', 11, 'Student', '2024-01-15', '2025-01-15', TRUE),
('MEM2024016', 'Victor', 'Chukwuemeka', 'Okoli', '1986-09-12', 'victor.okoli@outlook.com', '2348156789012', '78 Rumuola Road', 'Rumuola', 'Port Harcourt', 'Rivers State', 'Nigeria', 10, 'Premium', '2024-03-10', '2025-03-10', TRUE),

-- Ibadan members
('MEM2024017', 'Titilayo', 'Abosede', 'Ajayi', '1994-03-28', 'titi.ajayi@yahoo.com', '2348091234567', '23 Bodija Estate', 'Bodija', 'Ibadan', 'Oyo State', 'Nigeria', 12, 'Standard', '2024-01-30', '2025-01-30', TRUE),
('MEM2024018', 'Bolaji', 'Oluwaseun', 'Adekunle', '2001-08-19', 'bolaji.adekunle@student.edu.ng', '2347012345678', '45 UI Road', 'UI Campus', 'Ibadan', 'Oyo State', 'Nigeria', 11, 'Student', '2024-02-05', '2025-02-05', TRUE),
('MEM2024019', 'Olayinka', 'Temitope', 'Ogunleye', '1989-12-07', 'olayinka.ogunleye@gmail.com', '2348178901234', '67 Ring Road', 'Challenge', 'Ibadan', 'Oyo State', 'Nigeria', 12, 'Standard', '2023-12-15', '2024-12-15', TRUE),
('MEM2024020', 'Adebola', 'Folashade', 'Williams', '1975-06-22', 'adebola.williams@outlook.com', '2348054567890', '89 Lebanon Street', 'Bodija', 'Ibadan', 'Oyo State', 'Nigeria', 12, 'Senior', '2024-03-01', '2025-03-01', TRUE);

-- ============================================================================
-- INSERT loanS (Sample borrowing transactions)
-- ============================================================================

INSERT INTO loan (copy_id, member_id, branch_id, loan_date, due_date, return_date, renewal_count, `status`, fine_amount, fine_paid, staff_id, notes) VALUES
-- Active loans (not yet returned)
(1, 1, 2, '2024-11-01', '2024-11-22', NULL, 0, 'Active', 0.00, FALSE, 'STAFF001', 'First-time borrower'),
(15, 3, 1, '2024-11-05', '2024-11-26', NULL, 0, 'Active', 0.00, FALSE, 'STAFF002', NULL),
(22, 6, 5, '2024-11-08', '2024-11-29', NULL, 0, 'Active', 0.00, FALSE, 'STAFF005', NULL),
(35, 4, 4, '2024-11-10', '2024-12-01', NULL, 1, 'Active', 0.00, FALSE, 'STAFF004', 'Renewed once'),
(40, 7, 6, '2024-11-12', '2024-12-03', NULL, 0, 'Active', 0.00, FALSE, 'STAFF006', NULL),

-- Overdue loans
(8, 5, 1, '2024-10-15', '2024-11-05', NULL, 0, 'Overdue', 750.00, FALSE, 'STAFF001', 'member contacted on 2024-11-10'),
(25, 9, 6, '2024-10-20', '2024-11-10', NULL, 0, 'Overdue', 500.00, FALSE, 'STAFF006', 'Awaiting return'),

-- Recently returned loans
(2, 2, 2, '2024-10-15', '2024-11-05', '2024-11-03', 0, 'Returned', 0.00, TRUE, 'STAFF002', 'Returned early'),
(12, 1, 2, '2024-10-20', '2024-11-10', '2024-11-09', 0, 'Returned', 0.00, TRUE, 'STAFF002', NULL),
(18, 3, 1, '2024-10-10', '2024-10-31', '2024-11-02', 0, 'Returned', 100.00, TRUE, 'STAFF001', 'Late return - fine paid'),
(30, 8, 7, '2024-10-12', '2024-11-02', '2024-10-30', 0, 'Returned', 0.00, TRUE, 'STAFF007', 'On-time return'),
(45, 10, 5, '2024-10-18', '2024-11-08', '2024-11-07', 0, 'Returned', 0.00, TRUE, 'STAFF005', NULL),
(52, 11, 8, '2024-10-22', '2024-11-12', '2024-11-10', 0, 'Returned', 0.00, TRUE, 'STAFF008', NULL),
(60, 14, 10, '2024-10-25', '2024-11-15', '2024-11-14', 0, 'Returned', 0.00, TRUE, 'STAFF010', NULL),

-- Historical loans (older returns)
(3, 1, 2, '2024-09-01', '2024-09-22', '2024-09-20', 0, 'Returned', 0.00, TRUE, 'STAFF002', NULL),
(7, 2, 2, '2024-09-05', '2024-09-26', '2024-09-25', 0, 'Returned', 0.00, TRUE, 'STAFF002', NULL),
(14, 6, 5, '2024-09-10', '2024-10-01', '2024-09-28', 0, 'Returned', 0.00, TRUE, 'STAFF005', NULL),
(20, 7, 6, '2024-09-12', '2024-10-03', '2024-10-05', 0, 'Returned', 100.00, TRUE, 'STAFF006', 'Late return'),
(28, 10, 5, '2024-09-15', '2024-10-06', '2024-10-04', 0, 'Returned', 0.00, TRUE, 'STAFF005', NULL),
(33, 12, 9, '2024-09-18', '2024-10-09', '2024-10-08', 0, 'Returned', 0.00, TRUE, 'STAFF009', NULL),
(38, 15, 11, '2024-09-20', '2024-10-11', '2024-10-10', 0, 'Returned', 0.00, TRUE, 'STAFF011', NULL),
(42, 17, 12, '2024-09-22', '2024-10-13', '2024-10-12', 0, 'Returned', 0.00, TRUE, 'STAFF012', NULL),

-- August returns
(5, 3, 1, '2024-08-05', '2024-08-26', '2024-08-24', 0, 'Returned', 0.00, TRUE, 'STAFF001', NULL),
(11, 4, 4, '2024-08-10', '2024-08-31', '2024-08-30', 0, 'Returned', 0.00, TRUE, 'STAFF004', NULL),
(19, 8, 7, '2024-08-15', '2024-09-05', '2024-09-03', 0, 'Returned', 0.00, TRUE, 'STAFF007', NULL),
(26, 11, 8, '2024-08-18', '2024-09-08', '2024-09-10', 0, 'Returned', 100.00, TRUE, 'STAFF008', 'Late return'),
(34, 13, 8, '2024-08-20', '2024-09-10', '2024-09-09', 0, 'Returned', 0.00, TRUE, 'STAFF008', NULL),
(41, 16, 10, '2024-08-22', '2024-09-12', '2024-09-11', 0, 'Returned', 0.00, TRUE, 'STAFF010', NULL),
(48, 18, 11, '2024-08-25', '2024-09-15', '2024-09-14', 0, 'Returned', 0.00, TRUE, 'STAFF011', NULL),

-- More recent activity (October)
(4, 2, 2, '2024-10-01', '2024-10-22', '2024-10-20', 0, 'Returned', 0.00, TRUE, 'STAFF002', NULL),
(10, 5, 1, '2024-10-03', '2024-10-24', '2024-10-26', 0, 'Returned', 100.00, TRUE, 'STAFF001', 'Returned late'),
(16, 6, 5, '2024-10-05', '2024-10-26', '2024-10-25', 0, 'Returned', 0.00, TRUE, 'STAFF005', NULL),
(23, 9, 6, '2024-10-08', '2024-10-29', '2024-10-28', 0, 'Returned', 0.00, TRUE, 'STAFF006', NULL),
(31, 12, 9, '2024-10-10', '2024-10-31', '2024-10-29', 0, 'Returned', 0.00, TRUE, 'STAFF009', NULL),
(37, 14, 10, '2024-10-12', '2024-11-02', '2024-11-01', 0, 'Returned', 0.00, TRUE, 'STAFF010', NULL),
(44, 17, 12, '2024-10-15', '2024-11-05', '2024-11-04', 0, 'Returned', 0.00, TRUE, 'STAFF012', NULL),
(51, 19, 12, '2024-10-18', '2024-11-08', '2024-11-06', 0, 'Returned', 0.00, TRUE, 'STAFF012', NULL);

UPDATE loan
SET 
    loan_date = CONCAT(YEAR(CURDATE()), '-', MONTH(loan_date), '-', DAY(loan_date)),
    due_date = CONCAT(YEAR(CURDATE()), '-', MONTH(due_date), '-', DAY(due_date)),
    return_date = CASE 
        WHEN return_date IS NOT NULL 
        THEN CONCAT(YEAR(CURDATE()), '-', MONTH(return_date), '-', DAY(return_date))
        ELSE NULL 
    END
WHERE copy_id >= 0;


-- ============================================================================
-- INITIAL DATA: Populate payment types
-- ============================================================================
INSERT INTO payment_type (type_code, `name`, description) VALUES
('MEM_REG', 'Membership Registration', 'Initial registration fee for new members'),
('MEM_ANNUAL', 'Annual Membership Fee', 'Yearly membership subscription fee'),
('MEM_MONTHLY', 'Monthly Membership Fee', 'Monthly membership subscription fee'),
('MEM_RENEWAL', 'Membership Renewal', 'Fee for renewing expired membership'),
('FINE_LATE', 'Late Return Fine', 'Penalty for returning books after due date'),
('FINE_LOST', 'Lost Book Fine', 'Charge for lost or damaged books'),
('FINE_OTHER', 'Other Fines', 'Miscellaneous fines and charges');

-- ============================================================================
-- INITIAL DATA: Sample membership fee structures
-- ============================================================================
INSERT INTO membership_fee_structure (membership_type, annual_fee, monthly_fee, registration_fee, renewal_fee, effective_from) VALUES
('Standard', 5000.00, 500.00, 1000.00, 4500.00, '2025-01-01'),
('Student', 2500.00, 250.00, 500.00, 2000.00, '2025-01-01'),
('Senior', 3000.00, 300.00, 500.00, 2500.00, '2025-01-01'),
('Premium', 10000.00, 1000.00, 2000.00, 9000.00, '2025-01-01'),
('Staff', 0.00, 0.00, 0.00, 0.00, '2025-01-01'),
('Librarian', 0.00, 0.00, 0.00, 0.00, '2025-01-01');

-- ============================================================================
-- INITIAL DATA: Sample fine policies
-- ============================================================================
INSERT INTO fine_policy (policy_name, membership_type, daily_fine_rate, grace_period_days, maximum_fine, effective_from) VALUES
('Standard - Default', 'Standard', 50.00, 2, 5000.00, '2025-01-01'),
('Student - Default', 'Student', 25.00, 3, 2500.00, '2025-01-01'),
('Senior - Default', 'Senior', 30.00, 3, 3000.00, '2025-01-01'),
('Premium - Default', 'Premium', 40.00, 5, 4000.00, '2025-01-01'),
('Staff - Default', 'Staff', 20.00, 7, 2000.00, '2025-01-01'),
('Librarian - Default', 'Librarian', 0.00, 14, 0.00, '2025-01-01');



-- Composite indexes for common search patterns
CREATE INDEX idx_book_title_year ON book(title, publication_year);
CREATE INDEX idx_book_active_publisher ON book(is_active, id);
CREATE INDEX idx_copy_book_branch_status ON book_copy(book_id, branch_id, availability_status);
CREATE INDEX idx_loan_member_status ON loan(member_id, `status`);
