from fpdf import FPDF
import datetime
import os

class PDF(FPDF):
    """
    Custom PDF class to define a professional header and footer for all pages.
    """
    def header(self):
        # Set font for the header
        self.set_font('Arial', 'B', 20)
        self.set_text_color(34, 43, 69) # A dark blue for a professional look
        self.cell(0, 10, 'SysWarden Security Compliance Report', 0, 1, 'C')
        # Draw a subtle line below the header
        self.set_draw_color(220, 220, 220)
        self.line(10, 25, self.w - 10, 25)
        # Line break
        self.ln(15)

    def footer(self):
        # Position cursor at 1.5 cm from the bottom
        self.set_y(-15)
        # Set font for the footer
        self.set_font('Arial', 'I', 8)
        self.set_text_color(128) # Gray text
        # Add a page number with total pages
        self.cell(0, 10, f'Page {self.page_no()}/{{nb}}', 0, 0, 'C')

def generate_report(audit_results, os_type, level):
    """
    Generates a polished, professional PDF report from a list of audit result dictionaries.

    Args:
        audit_results (list): A list of dictionaries, where each dict represents a policy check.
        os_type (str): The operating system the audit was run on (e.g., "Windows", "Linux").
        level (str): The hardening level that was audited (e.g., "L1", "L3").

    Returns:
        str: The filename of the generated PDF report or an error message.
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
    
    # Draw a clean summary table
    pdf.set_font('Arial', 'B', 11)
    pdf.set_fill_color(240, 240, 240) # Header gray
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
    pdf.set_draw_color(200, 200, 200) # Border color for cards

    for result in audit_results:
        status = result.get('status', 'Error')
        parameter = result.get('parameter', 'Unknown Policy')
        details = result.get('details', 'No details were provided.')

        if status == 'Compliant':
            header_color = (220, 255, 220) # Light Green
        elif status == 'Not Compliant':
            header_color = (255, 220, 220) # Light Red
        else:
            header_color = (240, 240, 240) # Gray for Info/Error
        
        pdf.set_fill_color(*header_color)
        
        # Draw a "card" for each finding
        pdf.set_font('Arial', 'B', 11)
        pdf.multi_cell(0, 8, f"  {parameter}", 1, 'L', True)
        
        pdf.set_font('Arial', '', 10)
        # Use a nested table structure for clean alignment. This is a robust
        # way to prevent the FPDFException by controlling cell widths.
        pdf.cell(10, 6, '', 'L', 0) # Left padding
        pdf.cell(25, 6, 'Status:', 0, 0)
        pdf.multi_cell(0, 6, f"{status}", 'R', 'L')

        pdf.cell(10, 6, '', 'L', 0) # Left padding
        pdf.cell(25, 6, 'Details:', 0, 0)
        pdf.multi_cell(0, 6, f"{details}", 'R', 'L')
        
        # Draw the bottom border of the card
        pdf.cell(0, 0, '', 'T', 1)
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

