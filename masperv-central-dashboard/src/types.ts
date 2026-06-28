export type RiskLevel = 'Low' | 'Medium' | 'High';
export type CompanyStatus = 'Active' | 'Planning' | 'Restructuring';
export type EmployeeStatus = 'Active' | 'On Leave' | 'Contract';

export interface BusinessCategory {
  id: string;
  name: string;
  description: string;
  icon: string; // lucide icon name
  color: string; // tailwind color class
  riskLevel: RiskLevel;
}

export interface Company {
  id: string;
  name: string;
  categoryId: string;
  foundedYear: number;
  budget: number; // annual budget in USD
  status: CompanyStatus;
  description: string;
}

export interface ShoppingMall {
  id: string;
  name: string;
  location: string;
  gla: number; // Gross Leasable Area in sq ft
  storesCount: number;
  occupancyRate: number; // percentage (0 - 100)
  associatedCompanyId?: string; // which company manages/owns it
  annualFootfall: number; // in millions
  description: string;
}

export interface Employee {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: string;
  companyId: string; // associated company
  mallId?: string; // associated mall if they work at a mall specifically
  categoryId: string; // core operation category
  salary: number; // annual compensation in USD
  status: EmployeeStatus;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'model';
  text: string;
  timestamp: string;
  thinking?: string; // Optional thinking process returned by gemini-3.1-pro-preview
}
