-- Sanjeevani AI Telehealth Platform
-- Initial Schema Migration
-- Run this in Supabase SQL Editor

-- ─── EXTENSIONS ───
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ─── ENUMS ───
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('patient', 'doctor', 'admin');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE triage_status AS ENUM ('in_progress', 'completed', 'abandoned', 'emergency');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high', 'critical');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE consultation_status AS ENUM ('scheduled', 'waiting', 'active', 'completed', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE report_status AS ENUM ('draft', 'pending_review', 'signed', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE aftercare_status AS ENUM ('active', 'completed', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE checkin_status AS ENUM ('pending', 'completed', 'missed', 'escalated');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE notification_type AS ENUM ('checkin_reminder', 'medication_reminder', 'appointment_reminder', 'emergency_alert', 'care_letter_ready', 'report_signed');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE confidence_tier AS ENUM ('doctor_confirmed', 'patient_reported', 'ai_inferred');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ─── TABLES ───

-- profiles (extends auth.users 1:1)
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role NOT NULL DEFAULT 'patient',
  full_name text NOT NULL,
  date_of_birth date,
  biological_sex text CHECK (biological_sex IN ('male','female','prefer_not_to_say')),
  primary_language text DEFAULT 'en' CHECK (primary_language IN ('en','hi','both')),
  phone text,
  avatar_url text,
  is_verified boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- patient_profiles
CREATE TABLE IF NOT EXISTS patient_profiles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  allergies text[] DEFAULT '{}',
  chronic_conditions text[] DEFAULT '{}',
  current_medications jsonb DEFAULT '[]',
  blood_group text,
  emergency_contact_name text,
  emergency_contact_phone text,
  preferred_doctor_id uuid REFERENCES profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- doctor_profiles
CREATE TABLE IF NOT EXISTS doctor_profiles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  license_number text UNIQUE NOT NULL,
  specialty text NOT NULL,
  qualification text NOT NULL,
  years_experience int,
  hospital_affiliation text,
  consultation_fee numeric(10,2),
  is_available boolean DEFAULT true,
  bio text,
  mfa_enabled boolean DEFAULT false,
  mfa_secret text,
  license_verified_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- triage_sessions
CREATE TABLE IF NOT EXISTS triage_sessions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  status triage_status DEFAULT 'in_progress',
  voice_enabled boolean DEFAULT true,
  transcript jsonb DEFAULT '[]',
  confirmed_summary jsonb,
  raw_symptoms text,
  chief_complaint text,
  duration_seconds int,
  model_used_triage text,
  emergency_triggered boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

-- diagnostic_reports
CREATE TABLE IF NOT EXISTS diagnostic_reports (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  triage_session_id uuid UNIQUE NOT NULL REFERENCES triage_sessions(id),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  risk_level risk_level NOT NULL,
  chief_complaint text NOT NULL,
  differential_diagnoses jsonb NOT NULL,
  recommended_investigations text[],
  red_flags text[],
  clinical_notes text,
  confidence_statement text,
  doctor_acknowledged boolean DEFAULT false,
  doctor_acknowledged_at timestamptz,
  doctor_acknowledged_by uuid REFERENCES profiles(id),
  model_used text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- memory_bank
CREATE TABLE IF NOT EXISTS memory_bank (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  entry_type text NOT NULL,
  content text NOT NULL,
  structured_data jsonb,
  confidence_tier confidence_tier DEFAULT 'ai_inferred',
  relevance_vector vector(768),
  source_event_id uuid,
  source_event_type text,
  confirmed_by_doctor_id uuid REFERENCES profiles(id),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- consultations
CREATE TABLE IF NOT EXISTS consultations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  doctor_id uuid NOT NULL REFERENCES profiles(id),
  triage_session_id uuid REFERENCES triage_sessions(id),
  status consultation_status DEFAULT 'scheduled',
  scheduled_at timestamptz NOT NULL,
  started_at timestamptz,
  ended_at timestamptz,
  jitsi_room_name text UNIQUE,
  pre_visit_brief_viewed boolean DEFAULT false,
  pre_visit_brief_viewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- soap_reports
CREATE TABLE IF NOT EXISTS soap_reports (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  consultation_id uuid UNIQUE NOT NULL REFERENCES consultations(id),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  doctor_id uuid NOT NULL REFERENCES profiles(id),
  status report_status DEFAULT 'draft',
  subjective text,
  objective text,
  assessment text,
  plan text,
  draft_history jsonb DEFAULT '[]',
  diagnosis_codes text[],
  doctor_modifications text,
  model_used_soap text,
  signed_at timestamptz,
  signed_by uuid REFERENCES profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- care_letters
CREATE TABLE IF NOT EXISTS care_letters (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  soap_report_id uuid NOT NULL REFERENCES soap_reports(id),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  doctor_id uuid NOT NULL REFERENCES profiles(id),
  content_draft text,
  content_approved text,
  medications_list jsonb DEFAULT '[]',
  follow_up_instructions text,
  emergency_signs text,
  model_used_summary text,
  approved_at timestamptz,
  approved_by uuid REFERENCES profiles(id),
  patient_viewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- care_plans
CREATE TABLE IF NOT EXISTS care_plans (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  doctor_id uuid NOT NULL REFERENCES profiles(id),
  care_letter_id uuid REFERENCES care_letters(id),
  is_active boolean DEFAULT true,
  medications jsonb DEFAULT '[]',
  check_in_frequency text DEFAULT 'daily',
  check_in_time time DEFAULT '08:00:00',
  escalation_triggers text[],
  start_date date,
  end_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- check_ins
CREATE TABLE IF NOT EXISTS check_ins (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  care_plan_id uuid NOT NULL REFERENCES care_plans(id),
  status checkin_status DEFAULT 'pending',
  scheduled_at timestamptz NOT NULL,
  submitted_at timestamptz,
  responses jsonb,
  overall_score int,
  ai_assessment text,
  escalation_triggered boolean DEFAULT false,
  escalation_reason text,
  model_used text,
  created_at timestamptz DEFAULT now()
);

-- medication_logs
CREATE TABLE IF NOT EXISTS medication_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  care_plan_id uuid NOT NULL REFERENCES care_plans(id),
  medication_name text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  confirmed_at timestamptz,
  was_taken boolean,
  skipped_reason text,
  created_at timestamptz DEFAULT now()
);

-- notifications
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES profiles(id),
  type notification_type NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id uuid REFERENCES profiles(id),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  model_used text,
  input_summary text,
  output_summary text,
  ip_address inet,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- emergency_alerts
CREATE TABLE IF NOT EXISTS emergency_alerts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id uuid NOT NULL REFERENCES profiles(id),
  triggered_by text NOT NULL,
  source_id uuid,
  severity text NOT NULL,
  description text NOT NULL,
  notified_doctor_id uuid REFERENCES profiles(id),
  acknowledged_at timestamptz,
  acknowledged_by uuid REFERENCES profiles(id),
  resolved_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- ─── INDEXES ───
CREATE INDEX IF NOT EXISTS idx_triage_sessions_patient_id ON triage_sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_triage_sessions_status ON triage_sessions(status);
CREATE INDEX IF NOT EXISTS idx_diagnostic_reports_patient_id ON diagnostic_reports(patient_id);
CREATE INDEX IF NOT EXISTS idx_memory_bank_patient_id ON memory_bank(patient_id);
CREATE INDEX IF NOT EXISTS idx_memory_bank_vector ON memory_bank USING ivfflat (relevance_vector vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_consultations_patient_id ON consultations(patient_id);
CREATE INDEX IF NOT EXISTS idx_consultations_doctor_id ON consultations(doctor_id);
CREATE INDEX IF NOT EXISTS idx_consultations_status ON consultations(status);
CREATE INDEX IF NOT EXISTS idx_check_ins_patient_id ON check_ins(patient_id);
CREATE INDEX IF NOT EXISTS idx_check_ins_care_plan_id ON check_ins(care_plan_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_patient_id ON emergency_alerts(patient_id);

-- ─── FUNCTIONS ───

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, role, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'role', 'patient')::user_role,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─── TRIGGERS ───

-- Trigger on auth.users INSERT
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Triggers for updated_at columns
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_patient_profiles_updated_at ON patient_profiles;
CREATE TRIGGER update_patient_profiles_updated_at
  BEFORE UPDATE ON patient_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_doctor_profiles_updated_at ON doctor_profiles;
CREATE TRIGGER update_doctor_profiles_updated_at
  BEFORE UPDATE ON doctor_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_care_plans_updated_at ON care_plans;
CREATE TRIGGER update_care_plans_updated_at
  BEFORE UPDATE ON care_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_soap_reports_updated_at ON soap_reports;
CREATE TRIGGER update_soap_reports_updated_at
  BEFORE UPDATE ON soap_reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_memory_bank_updated_at ON memory_bank;
CREATE TRIGGER update_memory_bank_updated_at
  BEFORE UPDATE ON memory_bank
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─── ROW LEVEL SECURITY ───

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE triage_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE diagnostic_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_bank ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE soap_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE care_letters ENABLE ROW LEVEL SECURITY;
ALTER TABLE care_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_alerts ENABLE ROW LEVEL SECURITY;

-- profiles policies
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Doctors can view their patients"
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM patient_profiles pp
      WHERE pp.user_id = id
      AND pp.preferred_doctor_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM consultations c
      WHERE c.patient_id = id
      AND c.doctor_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- patient_profiles policies
CREATE POLICY "Users can view own patient profile"
  ON patient_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Doctors can view their patients' profiles"
  ON patient_profiles FOR SELECT
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
    AND (
      preferred_doctor_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM consultations c
        WHERE c.patient_id = user_id
        AND c.doctor_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can update own patient profile"
  ON patient_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Doctors can update their patients' profiles"
  ON patient_profiles FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
    AND (
      preferred_doctor_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM consultations c
        WHERE c.patient_id = user_id
        AND c.doctor_id = auth.uid()
      )
    )
  );

-- doctor_profiles policies
CREATE POLICY "Everyone can view doctor profiles"
  ON doctor_profiles FOR SELECT
  USING (true);

CREATE POLICY "Doctors can update own profile"
  ON doctor_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- triage_sessions policies
CREATE POLICY "Patients can view own triage sessions"
  ON triage_sessions FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Patients can insert own triage sessions"
  ON triage_sessions FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients can update own triage sessions"
  ON triage_sessions FOR UPDATE
  USING (auth.uid() = patient_id);

-- diagnostic_reports policies (DOCTOR ONLY - patients have NO access)
CREATE POLICY "Doctors can view diagnostic reports"
  ON diagnostic_reports FOR SELECT
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
  );

CREATE POLICY "Doctors can insert diagnostic reports"
  ON diagnostic_reports FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
  );

CREATE POLICY "Doctors can update diagnostic reports"
  ON diagnostic_reports FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
  );

-- memory_bank policies
CREATE POLICY "Patients can view own memory bank"
  ON memory_bank FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Doctors can view memory bank for their patients"
  ON memory_bank FOR SELECT
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
    AND (
      EXISTS (
        SELECT 1 FROM patient_profiles pp
        WHERE pp.user_id = patient_id
        AND pp.preferred_doctor_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM consultations c
        WHERE c.patient_id = patient_id
        AND c.doctor_id = auth.uid()
      )
    )
  );

CREATE POLICY "Patients can insert own memory bank entries"
  ON memory_bank FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients can update own memory bank"
  ON memory_bank FOR UPDATE
  USING (auth.uid() = patient_id);

CREATE POLICY "Doctors can insert memory bank for their patients"
  ON memory_bank FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
    AND (
      EXISTS (
        SELECT 1 FROM patient_profiles pp
        WHERE pp.user_id = patient_id
        AND pp.preferred_doctor_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM consultations c
        WHERE c.patient_id = patient_id
        AND c.doctor_id = auth.uid()
      )
    )
  );

-- consultations policies
CREATE POLICY "Patients can view own consultations"
  ON consultations FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Doctors can view own consultations"
  ON consultations FOR SELECT
  USING (auth.uid() = doctor_id);

CREATE POLICY "Patients can insert consultations"
  ON consultations FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Doctors can update consultations"
  ON consultations FOR UPDATE
  USING (auth.uid() = doctor_id);

-- soap_reports policies (DOCTOR ONLY - patients have NO access)
CREATE POLICY "Doctors can view soap reports"
  ON soap_reports FOR SELECT
  USING (auth.uid() = doctor_id);

CREATE POLICY "Doctors can insert soap reports"
  ON soap_reports FOR INSERT
  WITH CHECK (auth.uid() = doctor_id);

CREATE POLICY "Doctors can update soap reports"
  ON soap_reports FOR UPDATE
  USING (auth.uid() = doctor_id);

-- care_letters policies
CREATE POLICY "Patients can view approved care letters"
  ON care_letters FOR SELECT
  USING (
    auth.uid() = patient_id
    AND content_approved IS NOT NULL
  );

CREATE POLICY "Doctors can view care letters"
  ON care_letters FOR SELECT
  USING (auth.uid() = doctor_id);

CREATE POLICY "Doctors can insert care letters"
  ON care_letters FOR INSERT
  WITH CHECK (auth.uid() = doctor_id);

CREATE POLICY "Doctors can update care letters"
  ON care_letters FOR UPDATE
  USING (auth.uid() = doctor_id);

-- care_plans policies
CREATE POLICY "Patients can view own care plans"
  ON care_plans FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Doctors can view care plans for their patients"
  ON care_plans FOR SELECT
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
    AND (
      EXISTS (
        SELECT 1 FROM patient_profiles pp
        WHERE pp.user_id = patient_id
        AND pp.preferred_doctor_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM consultations c
        WHERE c.patient_id = patient_id
        AND c.doctor_id = auth.uid()
      )
    )
  );

CREATE POLICY "Doctors can insert care plans"
  ON care_plans FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
  );

CREATE POLICY "Doctors can update care plans"
  ON care_plans FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
  );

-- check_ins policies
CREATE POLICY "Patients can view own check-ins"
  ON check_ins FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Doctors can view check-ins for their patients"
  ON check_ins FOR SELECT
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
    AND (
      EXISTS (
        SELECT 1 FROM patient_profiles pp
        WHERE pp.user_id = patient_id
        AND pp.preferred_doctor_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM consultations c
        WHERE c.patient_id = patient_id
        AND c.doctor_id = auth.uid()
      )
    )
  );

CREATE POLICY "Patients can insert check-ins"
  ON check_ins FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

-- medication_logs policies
CREATE POLICY "Patients can view own medication logs"
  ON medication_logs FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Patients can insert medication logs"
  ON medication_logs FOR INSERT
  WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients can update own medication logs"
  ON medication_logs FOR UPDATE
  USING (auth.uid() = patient_id);

-- notifications policies
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- audit_logs policies (APPEND ONLY)
CREATE POLICY "Service role can insert audit logs"
  ON audit_logs FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Admins can view audit logs"
  ON audit_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'admin'
    )
  );

-- emergency_alerts policies
CREATE POLICY "Service role can insert emergency alerts"
  ON emergency_alerts FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Patients can view own emergency alerts"
  ON emergency_alerts FOR SELECT
  USING (auth.uid() = patient_id);

CREATE POLICY "Doctors can view emergency alerts for their patients"
  ON emergency_alerts FOR SELECT
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
    AND (
      EXISTS (
        SELECT 1 FROM patient_profiles pp
        WHERE pp.user_id = patient_id
        AND pp.preferred_doctor_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM consultations c
        WHERE c.patient_id = patient_id
        AND c.doctor_id = auth.uid()
      )
    )
  );

CREATE POLICY "Doctors can acknowledge emergency alerts"
  ON emergency_alerts FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT dp.user_id FROM doctor_profiles dp
      WHERE dp.user_id = auth.uid()
    )
  );
