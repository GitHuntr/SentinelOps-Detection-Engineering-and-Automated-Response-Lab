export interface Alert {
  id: string;
  external_id: string;
  rule_id: string;
  rule_description: string;
  severity_level: number;
  mitre_technique_id?: string;
  mitre_tactic?: string;
  agent_id: string;
  agent_name: string;
  agent_ip: string;
  occurrence_count: number;
  first_seen_at: string;
  last_seen_at: string;
  status: 'NEW' | 'TRIAGED' | 'DISMISSED';
}

export interface Incident {
  id: string;
  title: string;
  description?: string;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  status: 'NEW' | 'TRIAGED' | 'CONTAINING' | 'REMEDIATED' | 'CLOSED';
  assigned_to_user_id?: string;
  created_at: string;
  updated_at: string;
  alerts: Alert[];
}

export interface Playbook {
  id: string;
  name: string;
  description: string;
  is_disruptive: boolean;
  input_schema: Record<string, unknown>;
}

