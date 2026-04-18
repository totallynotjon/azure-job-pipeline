export interface AdzunaCategory {
  __CLASS__: "Adzuna::API::Response::Category";
  tag: string;
  label: string;
}

export interface AdzunaCompany {
  __CLASS__: "Adzuna::API::Response::Company";
  display_name: string;
}

export interface AdzunaLocation {
  __CLASS__: "Adzuna::API::Response::Location";
  display_name: string;
  area: string[];
}

export interface AdzunaJob {
  __CLASS__: "Adzuna::API::Response::Job";
  id: string;
  title: string;
  description: string;
  created: string;
  redirect_url: string;
  adref: string;
  category: AdzunaCategory;
  company: AdzunaCompany;
  location: AdzunaLocation;
  salary_is_predicted: "0" | "1";
  salary_min?: number;
  salary_max?: number;
  contract_type?: string;
  contract_time?: string;
  latitude?: number;
  longitude?: number;
}

export interface AdzunaJobSearchResults {
  __CLASS__: "Adzuna::API::Response::JobSearchResults";
  count: number;
  mean?: number;
  results?: AdzunaJob[];
}
