export interface Inspection {
  id: string;
  inspection_number: string;
  date: string;
  pe_id: string;
  pe_name?: string;
  inspector_id: string;
  inspector_name?: string;
  department_id: string;
  department_name?: string;
  contractor_id?: string;
  contractor_name?: string;
  work_location: string;
  source: 'mobile' | 'web';
  status: 'draft' | 'submitted' | 'approved';
  created_at: string;
}

export interface ViolationRecord {
  id?: string;
  inspection_id?: string;
  work_type_id: string;
  is_safe: boolean;
  violation_description?: string;
  is_gross_violation?: boolean;
  is_work_stopped?: boolean;
  zpb_rule_id?: string;
  is_top_violation: boolean;
  order: number;
}