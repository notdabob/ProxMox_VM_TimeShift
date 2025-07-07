#!/usr/bin/env python3
"""
Configuration Validation Script
Validates all configuration files in the ProxMox homelab setup
"""

import json
import yaml
import os
import sys
import ipaddress
from pathlib import Path
from typing import Dict, List, Any, Optional

class ConfigValidator:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.project_root = Path(__file__).parent.parent
        
    def log_error(self, message: str):
        """Log an error message"""
        self.errors.append(f"❌ ERROR: {message}")
        print(f"❌ ERROR: {message}")
    
    def log_warning(self, message: str):
        """Log a warning message"""
        self.warnings.append(f"⚠️  WARNING: {message}")
        print(f"⚠️  WARNING: {message}")
    
    def log_success(self, message: str):
        """Log a success message"""
        print(f"✅ {message}")
    
    def validate_yaml_file(self, file_path: Path) -> Optional[Dict]:
        """Validate YAML file syntax and return parsed content"""
        try:
            with open(file_path, 'r') as f:
                content = yaml.safe_load(f)
            self.log_success(f"YAML syntax valid: {file_path}")
            return content
        except yaml.YAMLError as e:
            self.log_error(f"YAML syntax error in {file_path}: {e}")
            return None
        except FileNotFoundError:
            self.log_error(f"File not found: {file_path}")
            return None
    
    def validate_json_file(self, file_path: Path) -> Optional[Dict]:
        """Validate JSON file syntax and return parsed content"""
        try:
            with open(file_path, 'r') as f:
                content = json.load(f)
            self.log_success(f"JSON syntax valid: {file_path}")
            return content
        except json.JSONDecodeError as e:
            self.log_error(f"JSON syntax error in {file_path}: {e}")
            return None
        except FileNotFoundError:
            self.log_error(f"File not found: {file_path}")
            return None
    
    def validate_network_config(self, config: Dict) -> bool:
        """Validate network configuration"""
        if not config:
            return False
            
        network_section = config.get('network', {})
        
        # Validate subnet format
        default_subnet = network_section.get('default_subnet')
        if default_subnet:
            try:
                ipaddress.ip_network(default_subnet, strict=False)
                self.log_success(f"Valid subnet format: {default_subnet}")
            except ValueError:
                self.log_error(f"Invalid subnet format: {default_subnet}")
        
        # Validate gateway IP
        default_gateway = network_section.get('default_gateway')
        if default_gateway:
            try:
                ipaddress.ip_address(default_gateway)
                self.log_success(f"Valid gateway IP: {default_gateway}")
            except ValueError:
                self.log_error(f"Invalid gateway IP: {default_gateway}")
        
        # Validate scan ranges
        scan_ranges = network_section.get('scan_ranges', [])
        for range_item in scan_ranges:
            try:
                ipaddress.ip_network(range_item, strict=False)
                self.log_success(f"Valid scan range: {range_item}")
            except ValueError:
                self.log_error(f"Invalid scan range: {range_item}")
        
        return True
    
    def validate_homelab_config(self, config: Dict) -> bool:
        """Validate homelab configuration"""
        if not config:
            return False
        
        # Check required sections
        required_sections = ['global', 'vm_standards', 'services']
        for section in required_sections:
            if section not in config:
                self.log_error(f"Missing required section: {section}")
            else:
                self.log_success(f"Found required section: {section}")
        
        # Validate VM ID ranges
        vm_standards = config.get('vm_standards', {})
        vmid_ranges = vm_standards.get('vmid_ranges', {})
        
        for service, range_str in vmid_ranges.items():
            if '-' in range_str:
                try:
                    start, end = map(int, range_str.split('-'))
                    if start >= end:
                        self.log_error(f"Invalid VMID range for {service}: {range_str}")
                    else:
                        self.log_success(f"Valid VMID range for {service}: {range_str}")
                except ValueError:
                    self.log_error(f"Invalid VMID range format for {service}: {range_str}")
        
        # Validate port mappings
        migration = config.get('migration', {})
        port_mapping = migration.get('port_mapping', {})
        
        for old_port, new_port in port_mapping.items():
            try:
                old_port_int = int(old_port)
                new_port_int = int(new_port)
                if not (1 <= old_port_int <= 65535) or not (1 <= new_port_int <= 65535):
                    self.log_error(f"Invalid port range: {old_port} -> {new_port}")
                else:
                    self.log_success(f"Valid port mapping: {old_port} -> {new_port}")
            except ValueError:
                self.log_error(f"Invalid port format: {old_port} -> {new_port}")
        
        return True
    
    def validate_docker_compose(self, file_path: Path) -> bool:
        """Validate Docker Compose configuration"""
        config = self.validate_yaml_file(file_path)
        if not config:
            return False
        
        # Check version
        version = config.get('version')
        if not version:
            self.log_error("Missing Docker Compose version")
        else:
            self.log_success(f"Docker Compose version: {version}")
        
        # Check services
        services = config.get('services', {})
        if not services:
            self.log_error("No services defined in Docker Compose")
            return False
        
        self.log_success(f"Found {len(services)} services")
        
        # Validate each service
        for service_name, service_config in services.items():
            self.validate_service_config(service_name, service_config)
        
        # Check networks
        networks = config.get('networks', {})
        if networks:
            self.log_success(f"Found {len(networks)} networks")
            for network_name, network_config in networks.items():
                self.validate_network_definition(network_name, network_config)
        
        return True
    
    def validate_service_config(self, service_name: str, config: Dict):
        """Validate individual service configuration"""
        # Check for security settings
        if 'security_opt' in config:
            self.log_success(f"{service_name}: Has security options")
        else:
            self.log_warning(f"{service_name}: Missing security options")
        
        # Check for resource limits
        deploy = config.get('deploy', {})
        resources = deploy.get('resources', {})
        if resources:
            self.log_success(f"{service_name}: Has resource limits")
        else:
            self.log_warning(f"{service_name}: Missing resource limits")
        
        # Check for health checks
        if 'healthcheck' in config:
            self.log_success(f"{service_name}: Has health check")
        else:
            self.log_warning(f"{service_name}: Missing health check")
    
    def validate_network_definition(self, network_name: str, config: Dict):
        """Validate network definition"""
        ipam = config.get('ipam', {})
        if ipam:
            ipam_config = ipam.get('config', [])
            for net_config in ipam_config:
                subnet = net_config.get('subnet')
                if subnet:
                    try:
                        ipaddress.ip_network(subnet, strict=False)
                        self.log_success(f"Network {network_name}: Valid subnet {subnet}")
                    except ValueError:
                        self.log_error(f"Network {network_name}: Invalid subnet {subnet}")
    
    def validate_api_config(self, config: Dict) -> bool:
        """Validate API configuration"""
        if not config:
            return False
        
        # Check CORS configuration
        cors = config.get('cors', {})
        if cors:
            allowed_origins = cors.get('allowed_origins', [])
            if allowed_origins:
                self.log_success(f"CORS: {len(allowed_origins)} allowed origins")
            else:
                self.log_warning("CORS: No allowed origins specified")
        
        # Check security settings
        security = config.get('security', {})
        if security:
            rate_limit = security.get('rate_limit', {})
            if rate_limit:
                self.log_success("Security: Rate limiting configured")
            else:
                self.log_warning("Security: No rate limiting configured")
        
        return True
    
    def run_validation(self) -> bool:
        """Run all validations"""
        print("🔍 Starting configuration validation...")
        print("=" * 50)
        
        # Validate YAML files
        yaml_files = [
            'config/homelab-config.yaml',
            'config/network-config.yaml',
            'docker/docker-compose.yaml',
            '.github/workflows/yaml-lint.yml'
        ]
        
        for yaml_file in yaml_files:
            file_path = self.project_root / yaml_file
            if file_path.exists():
                if 'homelab-config' in yaml_file:
                    config = self.validate_yaml_file(file_path)
                    self.validate_homelab_config(config)
                elif 'network-config' in yaml_file:
                    config = self.validate_yaml_file(file_path)
                    self.validate_network_config(config)
                elif 'docker-compose' in yaml_file:
                    self.validate_docker_compose(file_path)
                else:
                    self.validate_yaml_file(file_path)
            else:
                self.log_warning(f"File not found: {yaml_file}")
        
        # Validate JSON files
        json_files = [
            'docker/services/idrac-manager/config/api-config.json',
            '.vscode/settings.json',
            '.vscode/tasks.json'
        ]
        
        for json_file in json_files:
            file_path = self.project_root / json_file
            if file_path.exists():
                if 'api-config' in json_file:
                    config = self.validate_json_file(file_path)
                    self.validate_api_config(config)
                else:
                    self.validate_json_file(file_path)
            else:
                self.log_warning(f"File not found: {json_file}")
        
        # Print summary
        print("\n" + "=" * 50)
        print("📊 Validation Summary:")
        print(f"✅ Successes: {len([msg for msg in self.warnings + self.errors if '✅' in str(msg)])}")
        print(f"⚠️  Warnings: {len(self.warnings)}")
        print(f"❌ Errors: {len(self.errors)}")
        
        if self.errors:
            print("\n❌ Errors found:")
            for error in self.errors:
                print(f"  {error}")
        
        if self.warnings:
            print("\n⚠️  Warnings:")
            for warning in self.warnings:
                print(f"  {warning}")
        
        return len(self.errors) == 0

def main():
    """Main function"""
    validator = ConfigValidator()
    success = validator.run_validation()
    
    if success:
        print("\n🎉 All validations passed!")
        sys.exit(0)
    else:
        print("\n💥 Validation failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()