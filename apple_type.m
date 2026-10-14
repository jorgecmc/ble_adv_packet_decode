function resolved_type = apple_type(type)
switch type
    case '02'
        resolved_type = 'iBeacon';
    case '05'
        resolved_type = 'AirDrop';
    case '07'
        resolved_type = 'AirPods / Beats';
    case '0C'
        resolved_type = 'Handoff';
    case '0F'
        resolved_type = 'Nearby Action';
    case '10'
        resolved_type = 'Nearby Info';
    case '12'
        resolved_type = 'Find My';
    otherwise
        resolved_type = ['unknown, (' type ')'];
end
end