from fpdf import FPDF
import datetime
import os

class PDF(FPDF):
    """
    Custom PDF class to define a professional header and footer.
    """
    def header(self):
        # Optional: Add a logo
        # self.image('path/to/logo.png', 10, 8, 33)
        self.set_font('Arial', 'B', 20)
        self.set_text_color(34, 43, 69)
        self.cell(0, 10, 'SysWarden Security Compliance Report', 0, 1, 'C')
        self.set_draw_color(220, 220, 220)
        self.line(10, 25, 200, 25)
        self.ln(15)

    def footer(self):
        self.set_y(-15)
        self.set_font('Arial', 'I', 8)
        self.set_text_color(128)
        self.cell(0, 10, f'Page {self.page_no()}/{{nb}}', 0, 0, 'C')

def generate_report(audit_results, os_type, level):
    """
    Generates a polished, professional PDF report.
    """
    pdf = PDF()
    pdf.alias_nb_pages()
    pdf.add_page()
    
    # --- Report Header Section ---
    pdf.set_font('Arial', 'B', 14)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 10, "1. Scan Details", 0, 1)
    pdf.set_font('Arial', '', 11)
    pdf.cell(0, 7, f"   - Operating System: {os_type}", 0, 1)
    pdf.cell(0, 7, f"   - Compliance Level Audited: {level}", 0, 1)
    pdf.cell(0, 7, f"   - Report Generated: {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}", 0, 1)
    pdf.ln(10)

    # --- Executive Summary Section ---
    total = len(audit_results)
    compliant = sum(1 for r in audit_results if r.get('status') == 'Compliant')
    not_compliant = sum(1 for r in audit_results if r.get('status') == 'Not Compliant')
    
    pdf.set_font('Arial', 'B', 14)
    pdf.cell(0, 10, "2. Executive Summary", 0, 1)
    
    # Draw a summary table
    pdf.set_font('Arial', 'B', 11)
    pdf.set_fill_color(240, 240, 240)
    col_width = (pdf.w - pdf.l_margin - pdf.r_margin) / 2
    pdf.cell(col_width, 10, "Metric", 1, 0, 'C', True)
    pdf.cell(col_width, 10, "Result", 1, 1, 'C', True)
    
    pdf.set_font('Arial', '', 11)
    pdf.cell(col_width, 10, "Total Policies Checked", 1, 0, 'L')
    pdf.cell(col_width, 10, str(total), 1, 1, 'C')
    
    pdf.set_fill_color(220, 255, 220) # Light Green
    pdf.cell(col_width, 10, "Compliant Policies", 1, 0, 'L', True)
    pdf.cell(col_width, 10, str(compliant), 1, 1, 'C', True)
    
    pdf.set_fill_color(255, 220, 220) # Light Red
    pdf.cell(col_width, 10, "Non-Compliant Policies", 1, 0, 'L', True)
    pdf.cell(col_width, 10, str(not_compliant), 1, 1, 'C', True)
    pdf.ln(10)
    
    # --- Detailed Findings Section ---
    pdf.set_font('Arial', 'B', 14)
    pdf.cell(0, 10, "3. Detailed Compliance Findings", 0, 1)
    pdf.set_draw_color(200, 200, 200)

    for result in audit_results:
        status = result.get('status', 'Error')
        parameter = result.get('parameter', 'Unknown Policy')
        details = result.get('details', 'No details were provided.')

        if status == 'Compliant':
            border_color = (220, 255, 220)
        elif status == 'Not Compliant':
            border_color = (255, 220, 220)
        else:
            border_color = (240, 240, 240)
        
        pdf.set_fill_color(*border_color)
        
        pdf.set_font('Arial', 'B', 11)
        pdf.multi_cell(0, 8, f"  {parameter}", 1, 'L', True)
        
        pdf.set_font('Arial', '', 10)
        pdf.multi_cell(0, 6, f"     Status: {status}", 'LR', 'L')
        pdf.multi_cell(0, 6, f"     Details: {details}", 'LRB', 'L')
        pdf.ln(5)

    # --- Save the PDF File ---
    if not os.path.exists('reports'):
        os.makedirs('reports')
    report_name = f"reports/SysWarden_Report_{os_type}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    
    try:
        pdf.output(report_name)
        return report_name
    except Exception as e:
        return f"Error: Could not generate PDF. Reason: {e}"
