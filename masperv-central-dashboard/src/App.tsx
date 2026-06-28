import React, { useState, useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import * as Icons from 'lucide-react';
import {
  BusinessCategory,
  Company,
  ShoppingMall,
  Employee,
  ChatMessage,
  RiskLevel,
  CompanyStatus,
  EmployeeStatus
} from './types';
import {
  INITIAL_CATEGORIES,
  INITIAL_COMPANIES,
  INITIAL_MALLS,
  INITIAL_EMPLOYEES
} from './data';

// Dynamic Icon Component
function LucideIcon({ name, className = '', size = 20 }: { name: string; className?: string; size?: number }) {
  const IconComponent = (Icons as any)[name] || Icons.HelpCircle;
  return <IconComponent className={className} size={size} />;
}

// Custom Safe Markdown Renderer
function MarkdownRenderer({ text }: { text: string }) {
  const renderContent = (mdText: string) => {
    const lines = mdText.split('\n');
    const elements: React.ReactNode[] = [];
    let inList = false;
    let listItems: string[] = [];
    let inTable = false;
    let tableRows: string[][] = [];

    const flushList = (key: number) => {
      if (listItems.length > 0) {
        elements.push(
          <ul key={`ul-${key}`} className="list-disc pl-5 my-2 space-y-1.5 text-slate-700 text-sm">
            {listItems.map((item, idx) => (
              <li key={idx} dangerouslySetInnerHTML={{ __html: item }} />
            ))}
          </ul>
        );
        listItems = [];
        inList = false;
      }
    };

    const flushTable = (key: number) => {
      if (tableRows.length > 0) {
        const hasHeaders = tableRows.length > 1;
        const headers = hasHeaders ? tableRows[0] : [];
        const rows = hasHeaders ? tableRows.slice(1) : tableRows;

        elements.push(
          <div key={`table-wrapper-${key}`} className="overflow-x-auto my-3 border border-slate-200 rounded-lg shadow-sm">
            <table className="min-w-full divide-y divide-slate-200 text-xs text-left">
              {hasHeaders && (
                <thead className="bg-slate-50 text-slate-700 font-semibold">
                  <tr>
                    {headers.map((h, idx) => (
                      <th key={idx} className="px-3 py-2 border-b border-slate-200">{h}</th>
                    ))}
                  </tr>
                </thead>
              )}
              <tbody className="divide-y divide-slate-100 text-slate-600 bg-white">
                {rows.map((row, rIdx) => (
                  <tr key={rIdx} className={rIdx % 2 === 0 ? 'bg-white' : 'bg-slate-50/50'}>
                    {row.map((cell, cIdx) => (
                      <td key={cIdx} className="px-3 py-2 border-slate-100" dangerouslySetInnerHTML={{ __html: cell }} />
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        );
        tableRows = [];
        inTable = false;
      }
    };

    lines.forEach((line, index) => {
      let trimmed = line.trim();

      // Check Table
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        flushList(index);
        inTable = true;
        const cells = trimmed
          .split('|')
          .slice(1, -1)
          .map(c => parseInlineMarkdown(c.trim()));
        
        const isSeparator = cells.every(c => c.match(/^-+$/));
        if (!isSeparator) {
          tableRows.push(cells);
        }
        return;
      } else {
        if (inTable) {
          flushTable(index);
        }
      }

      // Headers
      if (trimmed.startsWith('### ')) {
        flushList(index);
        const headerText = parseInlineMarkdown(trimmed.substring(4));
        elements.push(<h4 key={index} className="text-sm font-bold text-slate-900 mt-4 mb-2 uppercase tracking-wide border-l-2 border-indigo-500 pl-2" dangerouslySetInnerHTML={{ __html: headerText }} />);
      } else if (trimmed.startsWith('## ')) {
        flushList(index);
        const headerText = parseInlineMarkdown(trimmed.substring(3));
        elements.push(<h3 key={index} className="text-base font-bold text-indigo-900 mt-5 mb-2.5 border-b border-indigo-100 pb-1" dangerouslySetInnerHTML={{ __html: headerText }} />);
      } else if (trimmed.startsWith('# ')) {
        flushList(index);
        const headerText = parseInlineMarkdown(trimmed.substring(2));
        elements.push(<h2 key={index} className="text-lg font-extrabold text-slate-900 mt-6 mb-3" dangerouslySetInnerHTML={{ __html: headerText }} />);
      }
      // Bullet lists
      else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        inList = true;
        const itemText = parseInlineMarkdown(trimmed.substring(2));
        listItems.push(itemText);
      } else {
        if (inList) {
          flushList(index);
        }

        if (trimmed === '') {
          return;
        }

        // Paragraph
        const paraText = parseInlineMarkdown(trimmed);
        elements.push(<p key={index} className="text-sm text-slate-700 leading-relaxed mb-2.5" dangerouslySetInnerHTML={{ __html: paraText }} />);
      }
    });

    if (inList) flushList(lines.length);
    if (inTable) flushTable(lines.length);

    return elements;
  };

  const parseInlineMarkdown = (inlineText: string) => {
    let html = inlineText;
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');
    html = html.replace(/`(.*?)`/g, '<code class="bg-indigo-50 text-indigo-700 px-1.5 py-0.5 rounded text-xs font-mono">$1</code>');
    return html;
  };

  return <div className="space-y-1">{renderContent(text)}</div>;
}

export default function App() {
  // --- Persistent Storage State ---
  const [categories, setCategories] = useState<BusinessCategory[]>(() => {
    const saved = localStorage.getItem('masperv_categories');
    return saved ? JSON.parse(saved) : INITIAL_CATEGORIES;
  });

  const [companies, setCompanies] = useState<Company[]>(() => {
    const saved = localStorage.getItem('masperv_companies');
    return saved ? JSON.parse(saved) : INITIAL_COMPANIES;
  });

  const [malls, setMalls] = useState<ShoppingMall[]>(() => {
    const saved = localStorage.getItem('masperv_malls');
    return saved ? JSON.parse(saved) : INITIAL_MALLS;
  });

  const [employees, setEmployees] = useState<Employee[]>(() => {
    const saved = localStorage.getItem('masperv_employees');
    return saved ? JSON.parse(saved) : INITIAL_EMPLOYEES;
  });

  const [chatHistory, setChatHistory] = useState<ChatMessage[]>(() => {
    const saved = localStorage.getItem('masperv_chat_history');
    return saved ? JSON.parse(saved) : [
      {
        id: 'msg-welcome',
        role: 'model',
        text: 'Welcome, Mr. Masperv. I am your Executive AI Strategic Partner. I have parsed all your commercial real estate assets, business categories, operational budgets, and key leadership team metrics. \n\nHow can I advise you today? You can choose a quick strategic analysis query below, or type your custom inquiry.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }
    ];
  });

  // Save to localStorage on changes
  useEffect(() => {
    localStorage.setItem('masperv_categories', JSON.stringify(categories));
  }, [categories]);

  useEffect(() => {
    localStorage.setItem('masperv_companies', JSON.stringify(companies));
  }, [companies]);

  useEffect(() => {
    localStorage.setItem('masperv_malls', JSON.stringify(malls));
  }, [malls]);

  useEffect(() => {
    localStorage.setItem('masperv_employees', JSON.stringify(employees));
  }, [employees]);

  useEffect(() => {
    localStorage.setItem('masperv_chat_history', JSON.stringify(chatHistory));
  }, [chatHistory]);

  // --- UI Navigation State ---
  const [activeTab, setActiveTab] = useState<'summary' | 'companies' | 'malls' | 'employees' | 'categories'>('summary');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState('all');
  const [selectedStatusFilter, setSelectedStatusFilter] = useState('all');

  // --- Real-time Clock ---
  const [currentTime, setCurrentTime] = useState(new Date());
  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  // --- Modal Forms State ---
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [formType, setFormType] = useState<'company' | 'mall' | 'employee' | 'category' | null>(null);
  const [editingItem, setEditingItem] = useState<any | null>(null);

  // Form Fields State (Generic Objects)
  const [companyForm, setCompanyForm] = useState<Partial<Company>>({
    name: '', categoryId: '', foundedYear: 2026, budget: 0, status: 'Active', description: ''
  });
  const [mallForm, setMallForm] = useState<Partial<ShoppingMall>>({
    name: '', location: '', gla: 0, storesCount: 0, occupancyRate: 90, associatedCompanyId: '', annualFootfall: 0, description: ''
  });
  const [employeeForm, setEmployeeForm] = useState<Partial<Employee>>({
    name: '', email: '', phone: '', role: '', companyId: '', categoryId: '', salary: 80000, status: 'Active'
  });
  const [categoryForm, setCategoryForm] = useState<Partial<BusinessCategory>>({
    name: '', description: '', icon: 'Layers', color: 'slate', riskLevel: 'Medium'
  });

  // --- AI Strategic Assistant State ---
  const [aiInput, setAiInput] = useState('');
  const [isAiLoading, setIsAiLoading] = useState(false);

  // --- Calculated Aggregate Metrics ---
  const totals = useMemo(() => {
    const totalBudget = companies.reduce((sum, c) => sum + (c.budget || 0), 0);
    const totalGLA = malls.reduce((sum, m) => sum + (m.gla || 0), 0);
    const totalEmployees = employees.length;
    const totalPayroll = employees.reduce((sum, e) => sum + (e.salary || 0), 0);
    const avgOccupancy = malls.length > 0 
      ? (malls.reduce((sum, m) => sum + (m.occupancyRate || 0), 0) / malls.length).toFixed(1)
      : '0';

    return { totalBudget, totalGLA, totalEmployees, totalPayroll, avgOccupancy };
  }, [companies, malls, employees]);

  // Budget by Category Chart Data
  const budgetByCategory = useMemo(() => {
    return categories.map(cat => {
      const catCompanies = companies.filter(c => c.categoryId === cat.id);
      const totalBudget = catCompanies.reduce((sum, c) => sum + c.budget, 0);
      const headCount = employees.filter(e => e.categoryId === cat.id).length;
      return {
        categoryName: cat.name,
        color: cat.color,
        icon: cat.icon,
        budget: totalBudget,
        headCount
      };
    });
  }, [categories, companies, employees]);

  // Max budget in single category for scale sizing
  const maxCategoryBudget = useMemo(() => {
    const budgets = budgetByCategory.map(b => b.budget);
    return Math.max(...budgets, 1);
  }, [budgetByCategory]);

  // Reset to original seed data
  const handleResetToDefaults = () => {
    if (confirm("Are you sure you want to reset all data to the default Masperv enterprise configurations?")) {
      setCategories(INITIAL_CATEGORIES);
      setCompanies(INITIAL_COMPANIES);
      setMalls(INITIAL_MALLS);
      setEmployees(INITIAL_EMPLOYEES);
      setChatHistory([
        {
          id: 'msg-welcome-reset',
          role: 'model',
          text: 'Enterprise database has been successfully synchronized and restored to factory defaults, Mr. Masperv. All operational ledgers, shopping malls metrics, and human resource profiles are active. How can I advise you today?',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        }
      ]);
      localStorage.removeItem('masperv_categories');
      localStorage.removeItem('masperv_companies');
      localStorage.removeItem('masperv_malls');
      localStorage.removeItem('masperv_employees');
      localStorage.removeItem('masperv_chat_history');
    }
  };

  // --- CRUD Operations Handlers ---

  // Open Add modal
  const openAddModal = (type: 'company' | 'mall' | 'employee' | 'category') => {
    setFormType(type);
    setEditingItem(null);
    setIsFormOpen(true);
    
    // Set default initializations
    if (type === 'company') {
      setCompanyForm({ name: '', categoryId: categories[0]?.id || '', foundedYear: 2026, budget: 1000000, status: 'Active', description: '' });
    } else if (type === 'mall') {
      setMallForm({ name: '', location: '', gla: 500000, storesCount: 100, occupancyRate: 92.5, associatedCompanyId: companies[0]?.id || '', annualFootfall: 10, description: '' });
    } else if (type === 'employee') {
      setEmployeeForm({ name: '', email: '', phone: '', role: '', companyId: companies[0]?.id || '', categoryId: categories[0]?.id || '', salary: 85000, status: 'Active' });
    } else if (type === 'category') {
      setCategoryForm({ name: '', description: '', icon: 'Layers', color: 'indigo', riskLevel: 'Medium' });
    }
  };

  // Open Edit modal
  const openEditModal = (type: 'company' | 'mall' | 'employee' | 'category', item: any) => {
    setFormType(type);
    setEditingItem(item);
    setIsFormOpen(true);

    if (type === 'company') {
      setCompanyForm({ ...item });
    } else if (type === 'mall') {
      setMallForm({ ...item });
    } else if (type === 'employee') {
      setEmployeeForm({ ...item });
    } else if (type === 'category') {
      setCategoryForm({ ...item });
    }
  };

  // Delete Action handler
  const handleDeleteItem = (type: 'company' | 'mall' | 'employee' | 'category', id: string, name: string) => {
    if (confirm(`Are you sure you want to delete "${name}" from Masperv's centralized system?`)) {
      if (type === 'company') {
        setCompanies(companies.filter(c => c.id !== id));
        // Remove association in employees & malls
        setEmployees(employees.map(e => e.companyId === id ? { ...e, companyId: '' } : e));
        setMalls(malls.map(m => m.associatedCompanyId === id ? { ...m, associatedCompanyId: undefined } : m));
      } else if (type === 'mall') {
        setMalls(malls.filter(m => m.id !== id));
        setEmployees(employees.map(e => e.mallId === id ? { ...e, mallId: undefined } : e));
      } else if (type === 'employee') {
        setEmployees(employees.filter(e => e.id !== id));
      } else if (type === 'category') {
        setCategories(categories.filter(cat => cat.id !== id));
        // Reset categoryId in companies & employees
        setCompanies(companies.map(c => c.categoryId === id ? { ...c, categoryId: '' } : c));
        setEmployees(employees.map(e => e.categoryId === id ? { ...e, categoryId: '' } : e));
      }
    }
  };

  // Submit Modal Form handler
  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (formType === 'company') {
      if (editingItem) {
        setCompanies(companies.map(c => c.id === editingItem.id ? { ...c, ...companyForm } as Company : c));
      } else {
        const newComp: Company = {
          id: `comp-${Date.now().toString().slice(-6)}`,
          ...(companyForm as Company)
        };
        setCompanies([...companies, newComp]);
      }
    } else if (formType === 'mall') {
      if (editingItem) {
        setMalls(malls.map(m => m.id === editingItem.id ? { ...m, ...mallForm } as ShoppingMall : m));
      } else {
        const newMall: ShoppingMall = {
          id: `mall-${Date.now().toString().slice(-6)}`,
          ...(mallForm as ShoppingMall)
        };
        setMalls([...malls, newMall]);
      }
    } else if (formType === 'employee') {
      // Incur proper category id from selected company if needed
      const comp = companies.find(c => c.id === employeeForm.companyId);
      const catId = comp ? comp.categoryId : employeeForm.categoryId || '';
      
      const empData = { ...employeeForm, categoryId: catId };

      if (editingItem) {
        setEmployees(employees.map(e => e.id === editingItem.id ? { ...e, ...empData } as Employee : e));
      } else {
        const newEmp: Employee = {
          id: `emp-${Date.now().toString().slice(-4)}`,
          ...(empData as Employee)
        };
        setEmployees([...employees, newEmp]);
      }
    } else if (formType === 'category') {
      if (editingItem) {
        setCategories(categories.map(cat => cat.id === editingItem.id ? { ...cat, ...categoryForm } as BusinessCategory : cat));
      } else {
        const newCat: BusinessCategory = {
          id: `cat-${Date.now().toString().slice(-6)}`,
          ...(categoryForm as BusinessCategory)
        };
        setCategories([...categories, newCat]);
      }
    }

    setIsFormOpen(false);
    setFormType(null);
    setEditingItem(null);
  };

  // --- AI Consulting Integration ---

  const triggerAiConsult = async (customPrompt?: string) => {
    const activePrompt = customPrompt || aiInput;
    if (!activePrompt.trim()) return;

    // Add user message to state
    const userMsg: ChatMessage = {
      id: `msg-user-${Date.now()}`,
      role: 'user',
      text: activePrompt,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    const updatedHistory = [...chatHistory, userMsg];
    setChatHistory(updatedHistory);
    setAiInput('');
    setIsAiLoading(true);

    try {
      const response = await fetch('/api/ai/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          prompt: activePrompt,
          messages: updatedHistory.slice(-6).map(m => ({ role: m.role, text: m.text })), // pass recent 6 messages
          categories,
          companies,
          malls,
          employees
        })
      });

      if (!response.ok) {
        throw new Error('Server returned an error status: ' + response.status);
      }

      const data = await response.json();
      
      const modelMsg: ChatMessage = {
        id: `msg-model-${Date.now()}`,
        role: 'model',
        text: data.text,
        thinking: data.thinking,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      setChatHistory(prev => [...prev, modelMsg]);
    } catch (error: any) {
      console.error('Error in AI advisory stream:', error);
      const errorMsg: ChatMessage = {
        id: `msg-error-${Date.now()}`,
        role: 'model',
        text: `**Operational Alert:** I encountered a system issue analyzing your request. \n\nDetails: *${error.message || String(error)}*. Please verify that your backend dev server is active and the \`GEMINI_API_KEY\` is configured in the Secrets panel.`,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setChatHistory(prev => [...prev, errorMsg]);
    } finally {
      setIsAiLoading(false);
    }
  };

  // Filtered lists for rendering
  const filteredCompanies = useMemo(() => {
    return companies.filter(c => {
      const matchesSearch = c.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
                            c.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            c.description.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCategory = selectedCategoryFilter === 'all' || c.categoryId === selectedCategoryFilter;
      const matchesStatus = selectedStatusFilter === 'all' || c.status === selectedStatusFilter;
      return matchesSearch && matchesCategory && matchesStatus;
    });
  }, [companies, searchQuery, selectedCategoryFilter, selectedStatusFilter]);

  const filteredMalls = useMemo(() => {
    return malls.filter(m => {
      const matchesSearch = m.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
                            m.location.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            m.description.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCompany = selectedStatusFilter === 'all' || m.associatedCompanyId === selectedStatusFilter;
      return matchesSearch && matchesCompany;
    });
  }, [malls, searchQuery, selectedStatusFilter]);

  const filteredEmployees = useMemo(() => {
    return employees.filter(e => {
      const matchesSearch = e.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            e.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            e.role.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            e.id.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCompany = selectedCategoryFilter === 'all' || e.companyId === selectedCategoryFilter;
      const matchesStatus = selectedStatusFilter === 'all' || e.status === selectedStatusFilter;
      return matchesSearch && matchesCompany && matchesStatus;
    });
  }, [employees, searchQuery, selectedCategoryFilter, selectedStatusFilter]);

  const activeCategoryIconOptions = [
    'Building2', 'ShoppingBag', 'Cpu', 'Truck', 'Coffee', 'Layers', 'Briefcase', 'DollarSign', 'Home', 'Users', 'Wrench', 'LineChart', 'Shield'
  ];

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col font-sans text-slate-800 antialiased selection:bg-indigo-100">
      
      {/* HEADER SECTION */}
      <header className="sticky top-0 z-40 bg-slate-900 text-white border-b border-slate-800 px-6 py-4 shadow-md flex flex-col md:flex-row justify-between items-center gap-4">
        <div className="flex items-center gap-3">
          <div className="bg-indigo-600 text-white px-3 py-1.5 rounded-lg font-black tracking-widest text-lg font-mono flex items-center gap-2 shadow">
            <Icons.Crown size={22} className="text-yellow-400" />
            <span>MASPERV</span>
          </div>
          <div className="h-6 w-[1px] bg-slate-700 hidden md:block"></div>
          <div>
            <h1 className="text-sm font-semibold text-slate-200 tracking-wider uppercase hidden md:block">
              Central Enterprise Control Console
            </h1>
            <p className="text-xs text-slate-400 hidden md:block font-mono">
              Real-time Asset, Personnel & Operational Ledger
            </p>
          </div>
        </div>

        {/* System telemetry info */}
        <div className="flex items-center gap-4 flex-wrap md:flex-nowrap">
          <div className="bg-slate-800 border border-slate-700/60 px-3 py-1.5 rounded-lg flex items-center gap-2.5 text-xs text-slate-300 font-mono shadow-inner">
            <span className="flex h-2 w-2 relative">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span>CEO AUTHENTICATED</span>
          </div>

          <div className="text-xs font-mono bg-slate-850 px-3 py-1.5 rounded border border-slate-800 text-slate-400">
            {currentTime.toLocaleDateString()} {currentTime.toLocaleTimeString()}
          </div>

          <button
            onClick={handleResetToDefaults}
            className="bg-slate-800 hover:bg-red-950 hover:text-red-300 hover:border-red-900 border border-slate-700/60 text-slate-300 text-xs px-2.5 py-1.5 rounded-lg font-mono transition-all flex items-center gap-1.5"
            title="Reset Database Defaults"
          >
            <Icons.RotateCcw size={13} />
            <span>RESET</span>
          </button>
        </div>
      </header>

      {/* EXECUTIVE TOP SUMMARY METRICS STRIP */}
      <section className="bg-white border-b border-slate-200 px-6 py-5 grid grid-cols-2 lg:grid-cols-4 gap-4 shadow-sm">
        <div className="p-4 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between shadow-sm">
          <div>
            <p className="text-xs font-medium text-slate-500 uppercase tracking-wider">Enterprise Budget</p>
            <h3 className="text-2xl font-black text-slate-900 mt-1 font-mono">
              ${(totals.totalBudget / 1000000).toFixed(1)}M
            </h3>
            <p className="text-xs text-slate-400 mt-1">Across {companies.length} active companies</p>
          </div>
          <div className="p-3 rounded-lg bg-emerald-50 text-emerald-600">
            <Icons.TrendingUp size={24} />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between shadow-sm">
          <div>
            <p className="text-xs font-medium text-slate-500 uppercase tracking-wider">Shopping Malls footprint</p>
            <h3 className="text-2xl font-black text-slate-900 mt-1 font-mono">
              {(totals.totalGLA / 1000000).toFixed(2)}M
            </h3>
            <p className="text-xs text-slate-400 mt-1">Sq Ft GLA across {malls.length} hubs</p>
          </div>
          <div className="p-3 rounded-lg bg-blue-50 text-blue-600">
            <Icons.Building2 size={24} />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between shadow-sm">
          <div>
            <p className="text-xs font-medium text-slate-500 uppercase tracking-wider">Malls Occupancy Rate</p>
            <h3 className="text-2xl font-black text-slate-900 mt-1 font-mono">
              {totals.avgOccupancy}%
            </h3>
            <div className="w-full bg-slate-200 rounded-full h-1.5 mt-2">
              <div 
                className="bg-indigo-600 h-1.5 rounded-full" 
                style={{ width: `${totals.avgOccupancy}%` }}
              ></div>
            </div>
          </div>
          <div className="p-3 rounded-lg bg-indigo-50 text-indigo-600">
            <Icons.PieChart size={24} />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between shadow-sm">
          <div>
            <p className="text-xs font-medium text-slate-500 uppercase tracking-wider">Total Personnel Payroll</p>
            <h3 className="text-2xl font-black text-slate-900 mt-1 font-mono">
              ${(totals.totalPayroll / 1000000).toFixed(2)}M
            </h3>
            <p className="text-xs text-slate-400 mt-1">{totals.totalEmployees} active executives & specialists</p>
          </div>
          <div className="p-3 rounded-lg bg-amber-50 text-amber-600">
            <Icons.Users size={24} />
          </div>
        </div>
      </section>

      {/* MAIN LAYOUT */}
      <div className="flex-1 flex flex-col lg:flex-row h-full">
        
        {/* LEFT WORKSPACE (2/3 width) */}
        <main className="flex-1 p-6 flex flex-col gap-6 overflow-y-auto">
          
          {/* NAVIGATION TABS */}
          <div className="flex border-b border-slate-200 gap-1 pb-px overflow-x-auto">
            <button
              onClick={() => { setActiveTab('summary'); setSearchQuery(''); }}
              className={`px-4 py-2.5 font-semibold text-sm rounded-t-lg transition-all flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'summary'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Icons.LayoutDashboard size={16} />
              <span>Executive Overview</span>
            </button>
            <button
              onClick={() => { setActiveTab('companies'); setSearchQuery(''); setSelectedCategoryFilter('all'); setSelectedStatusFilter('all'); }}
              className={`px-4 py-2.5 font-semibold text-sm rounded-t-lg transition-all flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'companies'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Icons.Briefcase size={16} />
              <span>Companies ({companies.length})</span>
            </button>
            <button
              onClick={() => { setActiveTab('malls'); setSearchQuery(''); setSelectedStatusFilter('all'); }}
              className={`px-4 py-2.5 font-semibold text-sm rounded-t-lg transition-all flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'malls'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Icons.ShoppingBag size={16} />
              <span>Shopping Malls ({malls.length})</span>
            </button>
            <button
              onClick={() => { setActiveTab('employees'); setSearchQuery(''); setSelectedCategoryFilter('all'); setSelectedStatusFilter('all'); }}
              className={`px-4 py-2.5 font-semibold text-sm rounded-t-lg transition-all flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'employees'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Icons.Users size={16} />
              <span>Employees ({employees.length})</span>
            </button>
            <button
              onClick={() => { setActiveTab('categories'); setSearchQuery(''); }}
              className={`px-4 py-2.5 font-semibold text-sm rounded-t-lg transition-all flex items-center gap-2 whitespace-nowrap ${
                activeTab === 'categories'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Icons.Layers size={16} />
              <span>Categories ({categories.length})</span>
            </button>
          </div>

          {/* TAB CONTENT PANEL */}
          <div className="flex-1">
            <AnimatePresence mode="wait">
              
              {/* TAB 1: EXECUTIVE SUMMARY */}
              {activeTab === 'summary' && (
                <motion.div
                  key="tab-summary"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="space-y-6"
                >
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    
                    {/* BENTO BLOCK: Budget distribution graph (SVG Bar Chart) */}
                    <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
                      <div className="flex justify-between items-center mb-4">
                        <h3 className="font-bold text-slate-800 text-sm tracking-wide uppercase">Operational Budget Allocation</h3>
                        <span className="text-xs bg-slate-100 px-2.5 py-1 rounded text-slate-500 font-mono">Dynamic Ledger</span>
                      </div>
                      
                      <div className="space-y-4">
                        {budgetByCategory.map((item, idx) => {
                          const percentage = (item.budget / maxCategoryBudget) * 100;
                          return (
                            <div key={idx} className="space-y-1.5">
                              <div className="flex justify-between text-xs font-semibold text-slate-700">
                                <span className="flex items-center gap-1.5">
                                  <LucideIcon name={item.icon} className="text-slate-400" size={14} />
                                  {item.categoryName}
                                </span>
                                <span className="font-mono">${(item.budget / 1000000).toFixed(1)}M ({item.headCount} Headcount)</span>
                              </div>
                              <div className="w-full bg-slate-100 h-3.5 rounded-md overflow-hidden flex shadow-inner">
                                <motion.div
                                  initial={{ width: 0 }}
                                  animate={{ width: `${percentage}%` }}
                                  transition={{ duration: 0.8, delay: idx * 0.1 }}
                                  className={`h-full bg-indigo-500 hover:bg-indigo-600 rounded-md transition-all`}
                                />
                              </div>
                            </div>
                          );
                        })}
                      </div>
                      <div className="mt-5 pt-4 border-t border-slate-100 flex justify-between items-center text-xs text-slate-500 font-mono">
                        <span>Total Portfolio Outlay:</span>
                        <span className="font-bold text-slate-800">${(totals.totalBudget / 1000000).toFixed(1)}M</span>
                      </div>
                    </div>

                    {/* BENTO BLOCK: Shopping Malls Occupancy Tracker */}
                    <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
                      <div className="flex justify-between items-center mb-4">
                        <h3 className="font-bold text-slate-800 text-sm tracking-wide uppercase">Real Estate Occupancy Index</h3>
                        <span className="text-xs bg-indigo-50 text-indigo-700 px-2 py-0.5 rounded font-mono font-bold">AVG {totals.avgOccupancy}%</span>
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                        {malls.map((mall, idx) => {
                          let progressColor = 'bg-emerald-500';
                          if (mall.occupancyRate < 88) progressColor = 'bg-amber-500';
                          if (mall.occupancyRate < 80) progressColor = 'bg-rose-500';
                          
                          return (
                            <div key={mall.id} className="p-3 rounded-lg bg-slate-50 border border-slate-100 space-y-2">
                              <div className="flex justify-between items-start gap-1">
                                <h4 className="font-bold text-xs text-slate-800 truncate" title={mall.name}>{mall.name}</h4>
                                <span className="text-2xs font-mono font-bold text-indigo-600 bg-white px-1.5 py-0.5 rounded shadow-sm shrink-0">
                                  {mall.occupancyRate}%
                                </span>
                              </div>
                              <div className="w-full bg-slate-200 rounded-full h-1.5">
                                <div className={`h-1.5 rounded-full ${progressColor}`} style={{ width: `${mall.occupancyRate}%` }}></div>
                              </div>
                              <div className="flex justify-between text-2xs text-slate-400 font-mono">
                                <span>{mall.storesCount} Stores</span>
                                <span>{mall.annualFootfall}M visits</span>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                      <p className="text-3xs text-slate-400 mt-4 font-mono text-center">
                        Gross Leasable Area managed by Masperv Estates Ltd.
                      </p>
                    </div>

                  </div>

                  {/* QUICK STATS & CONGLOMERATE OVERVIEW */}
                  <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
                    <h3 className="font-bold text-slate-800 text-sm tracking-wide uppercase mb-4">Enterprise Restructuring & Operations Summary</h3>
                    
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                      
                      {/* Active Status Box */}
                      <div className="p-4 rounded-xl border border-emerald-100 bg-emerald-50/20">
                        <div className="flex items-center gap-2 text-emerald-700 font-bold text-xs uppercase mb-1">
                          <Icons.CheckCircle2 size={14} />
                          <span>Active Scale</span>
                        </div>
                        <p className="text-xs text-slate-500">Fully operational holdings operating within target budget limits.</p>
                        <p className="text-lg font-mono font-black text-slate-800 mt-2">
                          {companies.filter(c => c.status === 'Active').length} Companies
                        </p>
                      </div>

                      {/* Restructuring Box */}
                      <div className="p-4 rounded-xl border border-amber-100 bg-amber-50/20">
                        <div className="flex items-center gap-2 text-amber-700 font-bold text-xs uppercase mb-1">
                          <Icons.AlertCircle size={14} />
                          <span>Restructuring</span>
                        </div>
                        <p className="text-xs text-slate-500">Undergoing financial remodeling or staff re-allocation policies.</p>
                        <p className="text-lg font-mono font-black text-slate-800 mt-2">
                          {companies.filter(c => c.status === 'Restructuring').length} Companies
                        </p>
                      </div>

                      {/* Planning Box */}
                      <div className="p-4 rounded-xl border border-indigo-100 bg-indigo-50/20">
                        <div className="flex items-center gap-2 text-indigo-700 font-bold text-xs uppercase mb-1">
                          <Icons.CalendarRange size={14} />
                          <span>Strategic Planning</span>
                        </div>
                        <p className="text-xs text-slate-500">Pending market analysis and capitalization approval before kickoff.</p>
                        <p className="text-lg font-mono font-black text-slate-800 mt-2">
                          {companies.filter(c => c.status === 'Planning').length} Companies
                        </p>
                      </div>

                    </div>
                  </div>

                  {/* AI INTEGRATION TRIGGER BLOCK */}
                  <div className="p-5 rounded-xl bg-gradient-to-r from-indigo-900 to-slate-900 text-white shadow-md flex flex-col md:flex-row justify-between items-center gap-4">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2 text-indigo-300 font-bold text-xs tracking-wider uppercase">
                        <Icons.Sparkles size={14} className="animate-pulse text-yellow-400" />
                        <span>Executive Strategy Advisory</span>
                      </div>
                      <h4 className="text-base font-bold">Ask Gemini pro to conduct a comprehensive SWOT review of Masperv</h4>
                      <p className="text-xs text-slate-300">Generates instant strategic reports regarding budgets, malls optimization, and staff salaries.</p>
                    </div>
                    <button
                      onClick={() => triggerAiConsult("Provide a comprehensive SWOT Analysis of Company Masperv based on our active companies, mall assets, categories, and employees.")}
                      className="bg-indigo-600 hover:bg-indigo-500 border border-indigo-500 text-white text-xs px-4 py-2.5 rounded-lg font-bold font-mono transition-all flex items-center gap-2 shrink-0 shadow-lg"
                    >
                      <span>RUN STRATEGIC AUDIT</span>
                      <Icons.ChevronRight size={14} />
                    </button>
                  </div>

                </motion.div>
              )}

              {/* TAB 2: COMPANIES */}
              {activeTab === 'companies' && (
                <motion.div
                  key="tab-companies"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="space-y-4"
                >
                  {/* Search and Filters */}
                  <div className="bg-white border border-slate-200 p-4 rounded-xl flex flex-col md:flex-row gap-4 items-center justify-between shadow-sm">
                    <div className="relative w-full md:w-72">
                      <Icons.Search className="absolute left-3 top-2.5 text-slate-400" size={16} />
                      <input
                        type="text"
                        placeholder="Search companies..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="w-full pl-9 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>

                    <div className="flex flex-wrap gap-2 w-full md:w-auto justify-end">
                      <select
                        value={selectedCategoryFilter}
                        onChange={(e) => setSelectedCategoryFilter(e.target.value)}
                        className="px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:outline-none"
                      >
                        <option value="all">All Categories</option>
                        {categories.map(cat => (
                          <option key={cat.id} value={cat.id}>{cat.name}</option>
                        ))}
                      </select>

                      <select
                        value={selectedStatusFilter}
                        onChange={(e) => setSelectedStatusFilter(e.target.value)}
                        className="px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:outline-none"
                      >
                        <option value="all">All Statuses</option>
                        <option value="Active">Active</option>
                        <option value="Planning">Planning</option>
                        <option value="Restructuring">Restructuring</option>
                      </select>

                      <button
                        onClick={() => openAddModal('company')}
                        className="bg-indigo-600 hover:bg-indigo-500 text-white text-xs px-3.5 py-2 rounded-lg font-bold flex items-center gap-1.5 transition-all"
                      >
                        <Icons.Plus size={14} />
                        <span>Add Company</span>
                      </button>
                    </div>
                  </div>

                  {/* Companies Table / Grid */}
                  <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                    <table className="min-w-full divide-y divide-slate-200 text-left text-xs">
                      <thead className="bg-slate-50 text-slate-600 uppercase font-mono tracking-wider">
                        <tr>
                          <th className="px-6 py-3.5 font-semibold">Company ID</th>
                          <th className="px-6 py-3.5 font-semibold">Name</th>
                          <th className="px-6 py-3.5 font-semibold">Category</th>
                          <th className="px-6 py-3.5 font-semibold">Founded</th>
                          <th className="px-6 py-3.5 font-semibold">Annual Budget</th>
                          <th className="px-6 py-3.5 font-semibold">Status</th>
                          <th className="px-6 py-3.5 font-semibold">Staff Count</th>
                          <th className="px-6 py-3.5 text-right font-semibold">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-200 text-slate-700 font-sans">
                        {filteredCompanies.length === 0 ? (
                          <tr>
                            <td colSpan={8} className="px-6 py-10 text-center text-slate-400 font-mono">
                              No companies match the search or filter criteria.
                            </td>
                          </tr>
                        ) : (
                          filteredCompanies.map(comp => {
                            const cat = categories.find(c => c.id === comp.categoryId);
                            const staffCount = employees.filter(e => e.companyId === comp.id).length;
                            
                            let badgeStyle = 'bg-emerald-50 text-emerald-700 border-emerald-200';
                            if (comp.status === 'Restructuring') badgeStyle = 'bg-amber-50 text-amber-700 border-amber-200';
                            if (comp.status === 'Planning') badgeStyle = 'bg-indigo-50 text-indigo-700 border-indigo-200';

                            return (
                              <tr key={comp.id} className="hover:bg-slate-50/55 transition-colors">
                                <td className="px-6 py-4 font-mono font-semibold text-indigo-600">{comp.id}</td>
                                <td className="px-6 py-4">
                                  <div className="font-bold text-slate-900 text-sm">{comp.name}</div>
                                  <div className="text-slate-400 text-2xs truncate max-w-xs">{comp.description}</div>
                                </td>
                                <td className="px-6 py-4">
                                  {cat ? (
                                    <span className="flex items-center gap-1.5">
                                      <LucideIcon name={cat.icon} size={14} className="text-slate-400" />
                                      {cat.name}
                                    </span>
                                  ) : (
                                    <span className="text-slate-400 font-mono text-2xs">None</span>
                                  )}
                                </td>
                                <td className="px-6 py-4 font-mono">{comp.foundedYear}</td>
                                <td className="px-6 py-4 font-mono font-bold">${(comp.budget).toLocaleString()}</td>
                                <td className="px-6 py-4">
                                  <span className={`px-2 py-0.5 rounded-full border text-2xs font-mono font-bold ${badgeStyle}`}>
                                    {comp.status}
                                  </span>
                                </td>
                                <td className="px-6 py-4 font-mono font-semibold">{staffCount} Members</td>
                                <td className="px-6 py-4 text-right">
                                  <div className="flex gap-2 justify-end">
                                    <button
                                      onClick={() => openEditModal('company', comp)}
                                      className="p-1.5 text-slate-500 hover:text-indigo-600 hover:bg-slate-100 rounded transition-colors"
                                      title="Edit Details"
                                    >
                                      <Icons.Edit3 size={14} />
                                    </button>
                                    <button
                                      onClick={() => handleDeleteItem('company', comp.id, comp.name)}
                                      className="p-1.5 text-slate-500 hover:text-red-600 hover:bg-slate-100 rounded transition-colors"
                                      title="Delete"
                                    >
                                      <Icons.Trash2 size={14} />
                                    </button>
                                  </div>
                                </td>
                              </tr>
                            );
                          })
                        )}
                      </tbody>
                    </table>
                  </div>
                </motion.div>
              )}

              {/* TAB 3: SHOPPING MALLS */}
              {activeTab === 'malls' && (
                <motion.div
                  key="tab-malls"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="space-y-4"
                >
                  {/* Controls */}
                  <div className="bg-white border border-slate-200 p-4 rounded-xl flex flex-col md:flex-row gap-4 items-center justify-between shadow-sm">
                    <div className="relative w-full md:w-72">
                      <Icons.Search className="absolute left-3 top-2.5 text-slate-400" size={16} />
                      <input
                        type="text"
                        placeholder="Search shopping malls..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="w-full pl-9 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>

                    <div className="flex gap-2 w-full md:w-auto justify-end">
                      <select
                        value={selectedStatusFilter}
                        onChange={(e) => setSelectedStatusFilter(e.target.value)}
                        className="px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:outline-none"
                      >
                        <option value="all">All Management Companies</option>
                        {companies.map(c => (
                          <option key={c.id} value={c.id}>{c.name}</option>
                        ))}
                      </select>

                      <button
                        onClick={() => openAddModal('mall')}
                        className="bg-indigo-600 hover:bg-indigo-500 text-white text-xs px-3.5 py-2 rounded-lg font-bold flex items-center gap-1.5 transition-all"
                      >
                        <Icons.Plus size={14} />
                        <span>Add Mall</span>
                      </button>
                    </div>
                  </div>

                  {/* Mall Cards */}
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {filteredMalls.length === 0 ? (
                      <div className="col-span-2 bg-white border border-slate-200 p-10 rounded-xl text-center text-slate-400 font-mono">
                        No shopping malls found matching filters.
                      </div>
                    ) : (
                      filteredMalls.map(mall => {
                        const managingComp = companies.find(c => c.id === mall.associatedCompanyId);
                        
                        let progressColor = 'bg-emerald-500';
                        if (mall.occupancyRate < 88) progressColor = 'bg-amber-500';
                        if (mall.occupancyRate < 80) progressColor = 'bg-rose-500';

                        return (
                          <div key={mall.id} className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4 hover:shadow-md transition-shadow">
                            <div className="flex justify-between items-start">
                              <div>
                                <span className="text-2xs font-mono font-semibold text-slate-400 block">{mall.id}</span>
                                <h3 className="font-extrabold text-base text-slate-900 mt-0.5">{mall.name}</h3>
                                <div className="text-xs text-slate-500 flex items-center gap-1 mt-1">
                                  <Icons.MapPin size={13} className="text-indigo-500" />
                                  <span>{mall.location}</span>
                                </div>
                              </div>
                              
                              <div className="flex gap-1.5">
                                <button
                                  onClick={() => openEditModal('mall', mall)}
                                  className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-slate-50 rounded"
                                  title="Edit"
                                >
                                  <Icons.Edit3 size={14} />
                                </button>
                                <button
                                  onClick={() => handleDeleteItem('mall', mall.id, mall.name)}
                                  className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-slate-50 rounded"
                                  title="Delete"
                                >
                                  <Icons.Trash2 size={14} />
                                </button>
                              </div>
                            </div>

                            <p className="text-xs text-slate-600">{mall.description}</p>

                            <div className="space-y-1">
                              <div className="flex justify-between text-xs font-semibold">
                                <span className="text-slate-500">Occupancy Rate</span>
                                <span className="font-mono text-slate-800 font-bold">{mall.occupancyRate}%</span>
                              </div>
                              <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                                <div className={`h-2 rounded-full ${progressColor}`} style={{ width: `${mall.occupancyRate}%` }}></div>
                              </div>
                            </div>

                            <div className="grid grid-cols-3 gap-2 pt-3 border-t border-slate-100 text-center text-xs font-mono">
                              <div className="p-2 rounded bg-slate-50 border border-slate-100">
                                <span className="text-3xs text-slate-400 block uppercase">Area (GLA)</span>
                                <span className="font-bold text-slate-800 text-xs">{(mall.gla / 1000).toFixed(0)}K sq ft</span>
                              </div>
                              <div className="p-2 rounded bg-slate-50 border border-slate-100">
                                <span className="text-3xs text-slate-400 block uppercase">Stores</span>
                                <span className="font-bold text-slate-800 text-xs">{mall.storesCount} units</span>
                              </div>
                              <div className="p-2 rounded bg-slate-50 border border-slate-100">
                                <span className="text-3xs text-slate-400 block uppercase">Footfall / yr</span>
                                <span className="font-bold text-slate-800 text-xs">{mall.annualFootfall}M visits</span>
                              </div>
                            </div>

                            <div className="flex justify-between items-center text-2xs text-slate-400 font-mono pt-1">
                              <span>Managed by:</span>
                              {managingComp ? (
                                <span className="text-indigo-600 font-bold">{managingComp.name}</span>
                              ) : (
                                <span className="text-slate-500">Unassigned</span>
                              )}
                            </div>
                          </div>
                        );
                      })
                    )}
                  </div>
                </motion.div>
              )}

              {/* TAB 4: EMPLOYEES */}
              {activeTab === 'employees' && (
                <motion.div
                  key="tab-employees"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="space-y-4"
                >
                  {/* Filters */}
                  <div className="bg-white border border-slate-200 p-4 rounded-xl flex flex-col md:flex-row gap-4 items-center justify-between shadow-sm">
                    <div className="relative w-full md:w-72">
                      <Icons.Search className="absolute left-3 top-2.5 text-slate-400" size={16} />
                      <input
                        type="text"
                        placeholder="Search employee names, emails, titles..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="w-full pl-9 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>

                    <div className="flex flex-wrap gap-2 w-full md:w-auto justify-end">
                      <select
                        value={selectedCategoryFilter}
                        onChange={(e) => setSelectedCategoryFilter(e.target.value)}
                        className="px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:outline-none"
                      >
                        <option value="all">All Companies</option>
                        {companies.map(c => (
                          <option key={c.id} value={c.id}>{c.name}</option>
                        ))}
                      </select>

                      <select
                        value={selectedStatusFilter}
                        onChange={(e) => setSelectedStatusFilter(e.target.value)}
                        className="px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:outline-none"
                      >
                        <option value="all">All Statuses</option>
                        <option value="Active">Active</option>
                        <option value="On Leave">On Leave</option>
                        <option value="Contract">Contract</option>
                      </select>

                      <button
                        onClick={() => openAddModal('employee')}
                        className="bg-indigo-600 hover:bg-indigo-500 text-white text-xs px-3.5 py-2 rounded-lg font-bold flex items-center gap-1.5 transition-all"
                      >
                        <Icons.Plus size={14} />
                        <span>Add Employee</span>
                      </button>
                    </div>
                  </div>

                  {/* Employee Ledger Table */}
                  <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                    <table className="min-w-full divide-y divide-slate-200 text-left text-xs">
                      <thead className="bg-slate-50 text-slate-600 uppercase font-mono tracking-wider">
                        <tr>
                          <th className="px-6 py-3.5 font-semibold">ID</th>
                          <th className="px-6 py-3.5 font-semibold">Employee</th>
                          <th className="px-6 py-3.5 font-semibold">Contact Info</th>
                          <th className="px-6 py-3.5 font-semibold">Role & Title</th>
                          <th className="px-6 py-3.5 font-semibold">Company Association</th>
                          <th className="px-6 py-3.5 font-semibold">Annual Compensation</th>
                          <th className="px-6 py-3.5 font-semibold">Status</th>
                          <th className="px-6 py-3.5 text-right font-semibold">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-200 text-slate-700 font-sans">
                        {filteredEmployees.length === 0 ? (
                          <tr>
                            <td colSpan={8} className="px-6 py-10 text-center text-slate-400 font-mono">
                              No employees found.
                            </td>
                          </tr>
                        ) : (
                          filteredEmployees.map(emp => {
                            const comp = companies.find(c => c.id === emp.companyId);
                            const mall = malls.find(m => m.id === emp.mallId);
                            const cat = categories.find(c => c.id === emp.categoryId);

                            let badgeStyle = 'bg-emerald-50 text-emerald-700 border-emerald-200';
                            if (emp.status === 'On Leave') badgeStyle = 'bg-amber-50 text-amber-700 border-amber-200';
                            if (emp.status === 'Contract') badgeStyle = 'bg-indigo-50 text-indigo-700 border-indigo-200';

                            return (
                              <tr key={emp.id} className="hover:bg-slate-50/55 transition-colors">
                                <td className="px-6 py-4 font-mono font-semibold text-indigo-600">{emp.id}</td>
                                <td className="px-6 py-4 font-bold text-slate-900">{emp.name}</td>
                                <td className="px-6 py-4">
                                  <div className="flex flex-col text-2xs space-y-0.5">
                                    <span className="text-slate-600 flex items-center gap-1">
                                      <Icons.Mail size={11} className="text-slate-400" />
                                      {emp.email}
                                    </span>
                                    <span className="text-slate-400 flex items-center gap-1">
                                      <Icons.Phone size={11} className="text-slate-400" />
                                      {emp.phone}
                                    </span>
                                  </div>
                                </td>
                                <td className="px-6 py-4">
                                  <div className="font-semibold text-slate-800">{emp.role}</div>
                                  {cat && (
                                    <span className="text-3xs text-indigo-600 font-mono flex items-center gap-0.5 mt-0.5">
                                      <LucideIcon name={cat.icon} size={10} />
                                      {cat.name}
                                    </span>
                                  )}
                                </td>
                                <td className="px-6 py-4">
                                  <div className="font-medium text-slate-800">{comp ? comp.name : 'Unassigned'}</div>
                                  {mall && (
                                    <div className="text-3xs text-slate-400 flex items-center gap-0.5 mt-0.5">
                                      <Icons.ShoppingBag size={10} />
                                      <span>Deployed: {mall.name}</span>
                                    </div>
                                  )}
                                </td>
                                <td className="px-6 py-4 font-mono font-bold text-slate-800">
                                  ${emp.salary.toLocaleString()}
                                </td>
                                <td className="px-6 py-4">
                                  <span className={`px-2 py-0.5 rounded-full border text-2xs font-mono font-bold ${badgeStyle}`}>
                                    {emp.status}
                                  </span>
                                </td>
                                <td className="px-6 py-4 text-right">
                                  <div className="flex gap-2 justify-end">
                                    <button
                                      onClick={() => openEditModal('employee', emp)}
                                      className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-slate-100 rounded"
                                      title="Edit"
                                    >
                                      <Icons.Edit3 size={14} />
                                    </button>
                                    <button
                                      onClick={() => handleDeleteItem('employee', emp.id, emp.name)}
                                      className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-slate-100 rounded"
                                      title="Delete"
                                    >
                                      <Icons.Trash2 size={14} />
                                    </button>
                                  </div>
                                </td>
                              </tr>
                            );
                          })
                        )}
                      </tbody>
                    </table>
                  </div>
                </motion.div>
              )}

              {/* TAB 5: CATEGORIES */}
              {activeTab === 'categories' && (
                <motion.div
                  key="tab-categories"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="space-y-4"
                >
                  <div className="flex justify-between items-center bg-white border border-slate-200 p-4 rounded-xl shadow-sm">
                    <div>
                      <h3 className="font-bold text-sm tracking-wide uppercase">Business Sectors & Operational Risks</h3>
                      <p className="text-xs text-slate-500">Definitions of core business spheres managed within the Masperv portfolio.</p>
                    </div>
                    <button
                      onClick={() => openAddModal('category')}
                      className="bg-indigo-600 hover:bg-indigo-500 text-white text-xs px-3.5 py-2 rounded-lg font-bold flex items-center gap-1.5 transition-all"
                    >
                      <Icons.Plus size={14} />
                      <span>Add Category</span>
                    </button>
                  </div>

                  {/* Category Cards */}
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {categories.map(cat => {
                      const associatedComps = companies.filter(c => c.categoryId === cat.id);
                      const totalCatBudget = associatedComps.reduce((sum, c) => sum + c.budget, 0);
                      const totalCatStaff = employees.filter(e => e.categoryId === cat.id).length;

                      let riskColor = 'bg-emerald-50 text-emerald-700 border-emerald-200';
                      if (cat.riskLevel === 'Medium') riskColor = 'bg-amber-50 text-amber-700 border-amber-200';
                      if (cat.riskLevel === 'High') riskColor = 'bg-rose-50 text-rose-700 border-rose-200';

                      return (
                        <div key={cat.id} className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm flex flex-col justify-between hover:shadow-md transition-shadow">
                          <div className="space-y-3">
                            <div className="flex justify-between items-start">
                              <div className="p-2 rounded-lg bg-slate-100 border border-slate-200">
                                <LucideIcon name={cat.icon} className="text-indigo-600" size={20} />
                              </div>
                              <div className="flex gap-1.5">
                                <button
                                  onClick={() => openEditModal('category', cat)}
                                  className="p-1 text-slate-400 hover:text-indigo-600"
                                >
                                  <Icons.Edit3 size={13} />
                                </button>
                                <button
                                  onClick={() => handleDeleteItem('category', cat.id, cat.name)}
                                  className="p-1 text-slate-400 hover:text-red-600"
                                >
                                  <Icons.Trash2 size={13} />
                                </button>
                              </div>
                            </div>

                            <div>
                              <span className="text-3xs font-mono font-semibold text-slate-400 uppercase">{cat.id}</span>
                              <h4 className="font-extrabold text-sm text-slate-900 mt-0.5">{cat.name}</h4>
                            </div>

                            <p className="text-xs text-slate-600 line-clamp-3">{cat.description}</p>
                          </div>

                          <div className="pt-4 mt-4 border-t border-slate-100 space-y-3.5">
                            <div className="flex justify-between items-center text-xs">
                              <span className="text-slate-400">Risk Profile:</span>
                              <span className={`px-2 py-0.5 rounded-full border text-3xs font-mono font-bold uppercase ${riskColor}`}>
                                {cat.riskLevel}
                              </span>
                            </div>

                            <div className="grid grid-cols-2 gap-2 text-center text-xs font-mono">
                              <div className="p-1.5 bg-slate-50 border border-slate-100 rounded">
                                <span className="text-3xs text-slate-400 block uppercase">Sub-Companies</span>
                                <span className="font-bold text-slate-800 text-xs">{associatedComps.length} units</span>
                              </div>
                              <div className="p-1.5 bg-slate-50 border border-slate-100 rounded">
                                <span className="text-3xs text-slate-400 block uppercase">Sector Budget</span>
                                <span className="font-bold text-slate-800 text-xs">${(totalCatBudget / 1000000).toFixed(1)}M</span>
                              </div>
                            </div>

                            <p className="text-3xs text-slate-400 font-mono text-right">
                              Contains {totalCatStaff} total operations team members
                            </p>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </motion.div>
              )}

            </AnimatePresence>
          </div>
        </main>

        {/* RIGHT AI CONSULTANT DRAWER (1/3 width) */}
        <aside className="w-full lg:w-96 border-t lg:border-t-0 lg:border-l border-slate-200 bg-white flex flex-col h-[600px] lg:h-auto shrink-0 shadow-lg">
          
          {/* AI Header */}
          <div className="p-4 bg-slate-900 text-white border-b border-slate-800 flex items-center justify-between shadow-sm shrink-0">
            <div className="flex items-center gap-2">
              <div className="p-1.5 rounded-lg bg-indigo-600 text-white animate-pulse">
                <Icons.Sparkles size={16} />
              </div>
              <div>
                <h3 className="font-extrabold text-sm text-slate-100 tracking-wide uppercase">AI Strategy Advisor</h3>
                <span className="text-3xs text-indigo-400 font-mono uppercase block">Gemini-3.1-pro-preview High-Thinking</span>
              </div>
            </div>
            
            <button
              onClick={() => setChatHistory([
                {
                  id: `msg-${Date.now()}`,
                  role: 'model',
                  text: 'Strategic advisory logs cleared. How can I assist you with corporate planning, asset assessment, or budget optimization today, Mr. Masperv?',
                  timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                }
              ])}
              className="text-slate-400 hover:text-white"
              title="Clear Consultation Logs"
            >
              <Icons.Eraser size={14} />
            </button>
          </div>

          {/* AI Conversation Space */}
          <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-slate-50/50">
            <AnimatePresence initial={false}>
              {chatHistory.map((msg, index) => {
                const isModel = msg.role === 'model';
                return (
                  <motion.div
                    key={msg.id || index}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className={`flex flex-col ${isModel ? 'items-start' : 'items-end'} space-y-1`}
                  >
                    <div className="flex items-center gap-1.5 text-3xs text-slate-400 font-mono">
                      <span>{isModel ? 'MASPERV AI ADVISOR' : 'CHIEF EXECUTIVE'}</span>
                      <span>•</span>
                      <span>{msg.timestamp}</span>
                    </div>

                    <div
                      className={`max-w-[90%] rounded-xl px-3.5 py-2.5 shadow-sm text-sm leading-relaxed ${
                        isModel
                          ? 'bg-white border border-slate-200/80 text-slate-800 rounded-tl-none'
                          : 'bg-indigo-600 text-white rounded-tr-none'
                      }`}
                    >
                      {isModel ? (
                        <MarkdownRenderer text={msg.text} />
                      ) : (
                        <p className="whitespace-pre-wrap">{msg.text}</p>
                      )}
                    </div>
                  </motion.div>
                );
              })}
            </AnimatePresence>

            {/* Simulated Animated Thinking State */}
            {isAiLoading && (
              <div className="flex flex-col items-start space-y-1">
                <div className="text-3xs text-slate-400 font-mono uppercase animate-pulse">
                  AI CONSULTANT IS REASONING... (HIGH THINKING MODE)
                </div>
                <div className="bg-slate-900 text-slate-100 border border-slate-800 rounded-xl px-4 py-3 rounded-tl-none shadow-md max-w-[90%] space-y-3">
                  <div className="flex items-center gap-2">
                    <Icons.Settings size={14} className="animate-spin text-indigo-400" />
                    <span className="text-xs font-mono font-bold text-slate-300">Evaluating corporate parameters...</span>
                  </div>
                  
                  {/* Micro simulated logs of deep reasoning */}
                  <div className="text-3xs text-slate-400 font-mono space-y-1 pl-5 border-l border-slate-800">
                    <p className="animate-pulse">▶ Aggregating {companies.length} business entities & annual outlays...</p>
                    <p className="animation-delay-200 animate-pulse">▶ Aligning occupancy rate metrics across shopping malls...</p>
                    <p className="animation-delay-500 animate-pulse">▶ Cross-checking payroll compensation parameters...</p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Quick Consult Templates */}
          <div className="p-3 bg-white border-t border-slate-100 shrink-0">
            <span className="text-3xs text-slate-400 uppercase font-mono tracking-wider block mb-2 font-bold">Strategic Report Shortcuts:</span>
            <div className="flex flex-wrap gap-1.5">
              <button
                onClick={() => triggerAiConsult("Assess our operational risk. Cross-examine the budget sizes of each Business Category and pinpoint where capital risk is highest.")}
                className="text-2xs bg-slate-50 hover:bg-indigo-50 hover:text-indigo-600 border border-slate-200 hover:border-indigo-200 text-slate-600 px-2 py-1 rounded transition-colors text-left"
              >
                ⚠️ Operational Risk Audit
              </button>
              <button
                onClick={() => triggerAiConsult("How can we optimize our shopping malls occupancy rates? Particularly look at Masperv Crestwood Mall (85.5% occupancy) and advise on a marketing or tenancy restructuring program.")}
                className="text-2xs bg-slate-50 hover:bg-indigo-50 hover:text-indigo-600 border border-slate-200 hover:border-indigo-200 text-slate-600 px-2 py-1 rounded transition-colors text-left"
              >
                🛍️ Mall Tenancy Plan
              </button>
              <button
                onClick={() => triggerAiConsult("Conduct a review of our leadership compensation and staff allocation. Are we overpaying or under-allocating personnel based on sector budgets?")}
                className="text-2xs bg-slate-50 hover:bg-indigo-50 hover:text-indigo-600 border border-slate-200 hover:border-indigo-200 text-slate-600 px-2 py-1 rounded transition-colors text-left"
              >
                👥 Human Capital Review
              </button>
            </div>
          </div>

          {/* Input Console */}
          <div className="p-3 bg-white border-t border-slate-200 shrink-0 flex gap-2">
            <input
              type="text"
              value={aiInput}
              onChange={(e) => setAiInput(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && triggerAiConsult()}
              placeholder="Ask for business recommendations..."
              disabled={isAiLoading}
              className="flex-1 bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 disabled:opacity-50"
            />
            <button
              onClick={() => triggerAiConsult()}
              disabled={isAiLoading || !aiInput.trim()}
              className="bg-indigo-600 hover:bg-indigo-500 text-white p-2 rounded-lg transition-colors disabled:opacity-40"
            >
              <Icons.Send size={16} />
            </button>
          </div>

        </aside>

      </div>

      {/* COMPACT MODAL FORMS: ADD & EDIT */}
      <AnimatePresence>
        {isFormOpen && formType && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="w-full max-w-md bg-white border border-slate-200 rounded-xl shadow-xl overflow-hidden"
            >
              <div className="px-5 py-4 bg-slate-900 text-white flex justify-between items-center">
                <h3 className="font-extrabold text-sm uppercase tracking-wider">
                  {editingItem ? 'Edit Details' : 'Add New Entry'} ({formType})
                </h3>
                <button
                  onClick={() => { setIsFormOpen(false); setFormType(null); setEditingItem(null); }}
                  className="text-slate-400 hover:text-white"
                >
                  <Icons.X size={18} />
                </button>
              </div>

              <form onSubmit={handleFormSubmit} className="p-5 space-y-4">
                
                {/* COMPANY FORM */}
                {formType === 'company' && (
                  <div className="space-y-3.5">
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Company Name</label>
                      <input
                        type="text"
                        required
                        value={companyForm.name}
                        onChange={(e) => setCompanyForm({ ...companyForm, name: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Operational Category</label>
                      <select
                        required
                        value={companyForm.categoryId}
                        onChange={(e) => setCompanyForm({ ...companyForm, categoryId: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      >
                        {categories.map(cat => (
                          <option key={cat.id} value={cat.id}>{cat.name}</option>
                        ))}
                      </select>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Year Founded</label>
                        <input
                          type="number"
                          required
                          value={companyForm.foundedYear}
                          onChange={(e) => setCompanyForm({ ...companyForm, foundedYear: parseInt(e.target.value) || 2026 })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm font-mono"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Annual Budget (USD)</label>
                        <input
                          type="number"
                          required
                          value={companyForm.budget}
                          onChange={(e) => setCompanyForm({ ...companyForm, budget: parseInt(e.target.value) || 0 })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm font-mono"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Operational Status</label>
                      <select
                        required
                        value={companyForm.status}
                        onChange={(e) => setCompanyForm({ ...companyForm, status: e.target.value as CompanyStatus })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      >
                        <option value="Active">Active</option>
                        <option value="Planning">Planning</option>
                        <option value="Restructuring">Restructuring</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Core Venture Description</label>
                      <textarea
                        value={companyForm.description}
                        onChange={(e) => setCompanyForm({ ...companyForm, description: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs h-20"
                      />
                    </div>
                  </div>
                )}

                {/* SHOPPING MALL FORM */}
                {formType === 'mall' && (
                  <div className="space-y-3.5">
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Mall Name</label>
                      <input
                        type="text"
                        required
                        value={mallForm.name}
                        onChange={(e) => setMallForm({ ...mallForm, name: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Location Address</label>
                      <input
                        type="text"
                        required
                        value={mallForm.location}
                        onChange={(e) => setMallForm({ ...mallForm, location: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">GLA (Sq Ft)</label>
                        <input
                          type="number"
                          required
                          value={mallForm.gla}
                          onChange={(e) => setMallForm({ ...mallForm, gla: parseInt(e.target.value) || 0 })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm font-mono"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Active Stores</label>
                        <input
                          type="number"
                          required
                          value={mallForm.storesCount}
                          onChange={(e) => setMallForm({ ...mallForm, storesCount: parseInt(e.target.value) || 0 })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm font-mono"
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Occupancy Rate (%)</label>
                        <input
                          type="number"
                          step="0.1"
                          required
                          min="0"
                          max="100"
                          value={mallForm.occupancyRate}
                          onChange={(e) => setMallForm({ ...mallForm, occupancyRate: parseFloat(e.target.value) || 0 })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm font-mono"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Annual Footfall (M)</label>
                        <input
                          type="number"
                          step="0.1"
                          required
                          value={mallForm.annualFootfall}
                          onChange={(e) => setMallForm({ ...mallForm, annualFootfall: parseFloat(e.target.value) || 0 })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm font-mono"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Managing Company Association</label>
                      <select
                        value={mallForm.associatedCompanyId || ''}
                        onChange={(e) => setMallForm({ ...mallForm, associatedCompanyId: e.target.value || undefined })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      >
                        <option value="">No Company Assigned</option>
                        {companies.map(c => (
                          <option key={c.id} value={c.id}>{c.name}</option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Property Description</label>
                      <textarea
                        value={mallForm.description}
                        onChange={(e) => setMallForm({ ...mallForm, description: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs h-16"
                      />
                    </div>
                  </div>
                )}

                {/* EMPLOYEE FORM */}
                {formType === 'employee' && (
                  <div className="space-y-3.5">
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Employee Full Name</label>
                      <input
                        type="text"
                        required
                        value={employeeForm.name}
                        onChange={(e) => setEmployeeForm({ ...employeeForm, name: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Corporate Email</label>
                        <input
                          type="email"
                          required
                          value={employeeForm.email}
                          onChange={(e) => setEmployeeForm({ ...employeeForm, email: e.target.value })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Phone Number</label>
                        <input
                          type="text"
                          required
                          value={employeeForm.phone}
                          onChange={(e) => setEmployeeForm({ ...employeeForm, phone: e.target.value })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs font-mono"
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Venture Association</label>
                        <select
                          required
                          value={employeeForm.companyId}
                          onChange={(e) => setEmployeeForm({ ...employeeForm, companyId: e.target.value })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs"
                        >
                          {companies.map(c => (
                            <option key={c.id} value={c.id}>{c.name}</option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Deployed Mall (Optional)</label>
                        <select
                          value={employeeForm.mallId || ''}
                          onChange={(e) => setEmployeeForm({ ...employeeForm, mallId: e.target.value || undefined })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs"
                        >
                          <option value="">Not Mall-Deployed</option>
                          {malls.map(m => (
                            <option key={m.id} value={m.id}>{m.name}</option>
                          ))}
                        </select>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Corporate Role</label>
                        <input
                          type="text"
                          required
                          value={employeeForm.role}
                          onChange={(e) => setEmployeeForm({ ...employeeForm, role: e.target.value })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Salary (Annual USD)</label>
                        <input
                          type="number"
                          required
                          value={employeeForm.salary}
                          onChange={(e) => setEmployeeForm({ ...employeeForm, salary: parseInt(e.target.value) || 0 })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm font-mono"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Employment Status</label>
                      <select
                        required
                        value={employeeForm.status}
                        onChange={(e) => setEmployeeForm({ ...employeeForm, status: e.target.value as EmployeeStatus })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      >
                        <option value="Active">Active</option>
                        <option value="On Leave">On Leave</option>
                        <option value="Contract">Contract</option>
                      </select>
                    </div>
                  </div>
                )}

                {/* CATEGORY FORM */}
                {formType === 'category' && (
                  <div className="space-y-3.5">
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Category Name</label>
                      <input
                        type="text"
                        required
                        value={categoryForm.name}
                        onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Venture Risk Profile</label>
                      <select
                        required
                        value={categoryForm.riskLevel}
                        onChange={(e) => setCategoryForm({ ...categoryForm, riskLevel: e.target.value as RiskLevel })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                      >
                        <option value="Low">Low Risk</option>
                        <option value="Medium">Medium Risk</option>
                        <option value="High">High Risk</option>
                      </select>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Display Icon</label>
                        <select
                          required
                          value={categoryForm.icon}
                          onChange={(e) => setCategoryForm({ ...categoryForm, icon: e.target.value })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                        >
                          {activeCategoryIconOptions.map(ico => (
                            <option key={ico} value={ico}>{ico}</option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Theme Accent Color</label>
                        <select
                          required
                          value={categoryForm.color}
                          onChange={(e) => setCategoryForm({ ...categoryForm, color: e.target.value })}
                          className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-sm"
                        >
                          <option value="emerald">Emerald Green</option>
                          <option value="blue">Blue Sky</option>
                          <option value="indigo">Indigo Tech</option>
                          <option value="amber">Amber Logistics</option>
                          <option value="rose">Rose Red</option>
                          <option value="purple">Purple Premium</option>
                          <option value="slate">Slate Professional</option>
                        </select>
                      </div>
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Venture Scope Description</label>
                      <textarea
                        required
                        value={categoryForm.description}
                        onChange={(e) => setCategoryForm({ ...categoryForm, description: e.target.value })}
                        className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs h-24"
                      />
                    </div>
                  </div>
                )}

                <div className="flex gap-2 justify-end pt-2 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => { setIsFormOpen(false); setFormType(null); setEditingItem(null); }}
                    className="px-4 py-2 text-xs border border-slate-200 rounded-lg font-semibold hover:bg-slate-50"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-4 py-2 text-xs bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-lg"
                  >
                    {editingItem ? 'Save Updates' : 'Create Entry'}
                  </button>
                </div>

              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

    </div>
  );
}
