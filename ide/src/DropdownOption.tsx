// TODO (michael): improve accessibilty by enabling these rules
/* eslint-disable jsx-a11y/click-events-have-key-events */
/* eslint-disable jsx-a11y/no-static-element-interactions */

import React from 'react';

export type DropdownOptionProps = {
  enabled: boolean,
  onClick: () => void,
};

export default function DropdownOption({ enabled, onClick, children }: DropdownOptionProps) {
  const internalName = `DropdownOption${new Date().getTime()}`;

  return (
    <div
      className={enabled ? 'run-option-enabled' : 'run-option-disabled'}
      onClick={onClick}
    >
      <input
        type="checkBox"
        checked={enabled}
        name={internalName}
        className="run-option-checkbox"
        readOnly
      />
      <label
        htmlFor={internalName}
        className="run-option-label"
      >
        {children}
      </label>
    </div>
  );
}
