import React from 'react';
import { Clock, Building, MapPin, Bus, MoreHorizontal } from 'lucide-react';

const categories = [
  { id: 'morning', label: 'Morning', icon: Clock },
  { id: 'evening', label: 'Evening', icon: Clock },
  { id: 'campus', label: 'Main Campus', icon: Building },
  { id: 'hostel', label: 'Hostel', icon: MapPin },
  { id: 'shuttle', label: 'Shuttle', icon: Bus },
];

const CategoryChips = ({ activeCategory, onCategoryChange }) => {
  return (
    <div className="gm-v3-chips-scroll">
      {categories.map((cat) => {
        const Icon = cat.icon;
        const isActive = activeCategory === cat.id;
        return (
          <button
            key={cat.id}
            onClick={() => onCategoryChange(cat.id)}
            className={`gm-v3-chip ${isActive ? 'active' : ''}`}
          >
            <Icon size={14} />
            <span>{cat.label}</span>
          </button>
        );
      })}
      <button className="gm-v3-chip">
        <MoreHorizontal size={14} />
        <span>More</span>
      </button>
    </div>
  );
};

export default CategoryChips;
