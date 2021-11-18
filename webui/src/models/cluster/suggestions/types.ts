export type CheckedServers = {
  [key: string]: boolean;
};

/*
 * It was decided to combine elements from 'config_locked' and 'config_mismatch'
 * into one group 'config_error'.
 */
export type ForceApplySuggestionByReason = [['operation_error', string[]], ['config_error', string[]]];

export interface SuggestionsPanelsVisibility {
  advertiseURI: boolean;
  disableServers: boolean;
  forceApply: boolean;
  restartReplication: boolean;
}
