function changed=cam_app_apply_ui_bindings(plan)
% Low-level transaction. Production callers prevalidate all identities/keys.
changed=0; applied=0;
try
    for k=1:numel(plan)
        plan(k).control.(plan(k).property)=plan(k).newCallback; applied=k; changed=changed+1;
    end
catch ex
    rollbackErrors={};
    for k=applied:-1:1
        try, plan(k).control.(plan(k).property)=plan(k).oldCallback;
        catch rollback, rollbackErrors{end+1}=rollback.message; end %#ok<AGROW>
    end
    if ~isempty(rollbackErrors)
        ex=addCause(ex,MException('cam:CallbackRollback','回滚失败：%s',strjoin(rollbackErrors,'; ')));
    end
    rethrow(ex);
end
end
