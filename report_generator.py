from fpdf import FPDF
import datetime
import os

class PDF(FPDF):
    """
    Custom PDF class to define a consistent header and footer for all pages.
    """
    def header(self):
        self.set_font('Arial', 'B', 16)
        self.cell(0, 10, 'SysWarden Security Compliance Report', 0, 1, 'C')
        self.ln(5)

    def footer(self):
        self.set_y(-15)
        self.set_font('Arial', 'I', 8)
        self.cell(0, 10, f'Page {self.page_no()}/{{nb}}', 0, 0, 'C')

def generate_report(audit_results, os_type, level):
    """
    Generates a detailed PDF report from a list of audit result dictionaries.
    """
    pdf = PDF()
    pdf.alias_nb_pages()
    pdf.add_page()
    
    # --- Report Header Section ---
    pdf.set_font('Arial', 'B', 12)
    pdf.cell(0, 10, "Scan Details", 0, 1)
    pdf.set_font('Arial', '', 10)
    pdf.cell(0, 6, f"Operating System: {os_type}", 0, 1)
    pdf.cell(0, 6, f"Compliance Level Audited: {level}", 0, 1)
    pdf.cell(0, 6, f"Report Generated: {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}", 0, 1)
    pdf.ln(10)

    # --- Executive Summary Section ---
    total_checks = len(audit_results)
    compliant = sum(1 for r in audit_results if r.get('status') == 'Compliant')
    not_compliant = sum(1 for r in audit_results if r.get('status') == 'Not Compliant')
    errors = total_checks - compliant - not_compliant
    
    pdf.set_font('Arial', 'B', 12)
    pdf.cell(0, 10, "Executive Summary", 0, 1)
    pdf.set_font('Arial', '', 10)
    
    pdf.set_fill_color(230, 230, 230)
    pdf.cell(60, 8, "Total Policies Checked:", 1, 0, 'L', True)
    pdf.cell(0, 8, str(total_checks), 1, 1)
    
    pdf.set_fill_color(200, 255, 200)
    pdf.cell(60, 8, "Compliant:", 1, 0, 'L', True)
    pdf.cell(0, 8, str(compliant), 1, 1)
    
    pdf.set_fill_color(255, 200, 200)
    pdf.cell(60, 8, "Not Compliant:", 1, 0, 'L', True)
    pdf.cell(0, 8, str(not_compliant), 1, 1)
    
    pdf.set_fill_color(255, 255, 200)
    pdf.cell(60, 8, "Errors / Not Applicable:", 1, 0, 'L', True)
    pdf.cell(0, 8, str(errors), 1, 1)
    pdf.ln(10)
    
    # --- Detailed Findings Section ---
    pdf.set_font('Arial', 'B', 12)
    pdf.cell(0, 10, "Detailed Compliance Findings", 0, 1)

    # *** THE FIX IS HERE ***
    # Calculate the effective page width for multi_cell to prevent overflow.
    effective_page_width = pdf.w - pdf.l_margin - pdf.r_margin

    for result in audit_results:
        status = result.get('status', 'Error')
        parameter = result.get('parameter', 'Unknown Policy')
        details = result.get('details', 'No details were provided by the module.')

        if status == 'Compliant':
            severity = "Low"
            pdf.set_text_color(34, 139, 34)
        elif status == 'Not Compliant':
            severity = "High"
            pdf.set_text_color(220, 20, 60)
        else:
            severity = "Informational"
            pdf.set_text_color(0, 0, 0)

        pdf.set_font('Arial', 'B', 10)
        pdf.multi_cell(effective_page_width, 6, f"Policy: {parameter}")
        
        pdf.set_font('Arial', '', 9)
        pdf.set_text_color(0, 0, 0)
        
        pdf.multi_cell(effective_page_width, 5, f"  Status: {status} (Severity: {severity})")
        pdf.multi_cell(effective_page_width, 5, f"  Details: {details}")
        pdf.ln(4)

    # --- Save the PDF File ---
    if not os.path.exists('reports'):
        os.makedirs('reports')
        
    report_name = f"reports/SysWarden_Report_{os_type}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    
    try:
        pdf.output(report_name)
        return report_name
    except Exception as e:
        return f"Error: Could not generate PDF. Reason: {e}"

